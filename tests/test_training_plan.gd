extends TestCase

const ORDER: Array[String] = ["CATEGORY_A", "CATEGORY_B", "CATEGORY_C"]


func _definitions() -> Array[DrillDefinition]:
	var out: Array[DrillDefinition] = []
	out.append(DrillDefinition.new(&"reaction_time", "T", "D", "s", "CATEGORY_A"))
	out.append(DrillDefinition.new(&"schulte_table", "T", "D", "s", "CATEGORY_A"))
	out.append(DrillDefinition.new(&"n_back", "T", "D", "s", "CATEGORY_B"))
	out.append(DrillDefinition.new(&"sart", "T", "D", "s", "CATEGORY_C"))
	return out


func test_suggest_respects_budget_and_rotates_categories() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var steps := TrainingPlan.suggest(_definitions(), 3, ORDER, rng)
	assert_true(steps.size() >= 2, "three minutes fit at least two short drills")
	assert_true(TrainingPlan.total_seconds(steps) <= 180, "stays within the budget")
	var first: String = steps[0]["drill_id"]
	assert_true(first == "reaction_time" or first == "schulte_table", "starts with the first category")
	if steps.size() >= 2:
		assert_eq(steps[1]["drill_id"], "n_back", "then the next category")
	# One minute still yields a step even if it overruns.
	var short := TrainingPlan.suggest(_definitions(), 1, ORDER, rng)
	assert_eq(short.size(), 1)
	# A long budget uses every drill once and stops.
	var long := TrainingPlan.suggest(_definitions(), 30, ORDER, rng)
	assert_eq(long.size(), 4)
	assert_true(TrainingPlan.suggest([] as Array[DrillDefinition], 10, ORDER, rng).is_empty())


func test_weak_categories_prefer_unplayed_then_low_levels() -> void:
	var history := StatsHistory.new()
	var r := DrillResult.new()
	r.drill_id = &"reaction_time"
	r.metrics = {"median_rt_ms": 170.0}
	r.finished_at_unix = 10
	history.add(StatsHistory.make_record(r))
	var s := DrillResult.new()
	s.drill_id = &"sart"
	s.metrics = {"mean_rt_ms": 500.0, "commission_rate": 0.3}
	s.finished_at_unix = 11
	history.add(StatsHistory.make_record(s))
	var order := TrainingPlan.weak_categories(_definitions(), history, ORDER)
	assert_eq(order, ["CATEGORY_B", "CATEGORY_C", "CATEGORY_A"] as Array[String], "unplayed B first, beginner C next, elite A last")


func test_plans_roundtrip() -> void:
	var steps: Array[Dictionary] = [TrainingPlan.make_step(&"sart"), TrainingPlan.make_step(&"n_back", {"n": 3})]
	var plans: Array[Dictionary] = [{"name": "Ráno", "steps": steps}]
	var text := TrainingPlan.serialize_plans(plans)
	var back := TrainingPlan.parse_plans(text)
	assert_eq(back.size(), 1)
	assert_eq(back[0]["name"], "Ráno")
	var back_steps: Array[Dictionary] = back[0]["steps"]
	assert_eq(back_steps.size(), 2)
	assert_eq(back_steps[1]["config"], {"n": 3.0})
	assert_true(TrainingPlan.parse_plans("{}").is_empty())
	assert_eq(TrainingPlan.estimate_seconds(&"sart"), 92)
	assert_eq(TrainingPlan.estimate_seconds(&"unknown"), 72)


func test_harder_configs_after_two_elite_runs() -> void:
	var history := StatsHistory.new()
	for i in 2:
		var r := DrillResult.new()
		r.drill_id = &"schulte_table"
		r.config = {"grid_size": 5, "symbols": "numbers"}
		r.metrics = {"total_ms": 15000.0, "errors": 0.0}
		r.finished_at_unix = 100 + i
		history.add(StatsHistory.make_record(r))
	assert_true(TrainingPlan.harder_configs(history).is_empty(), "the 5x5 variant key is not the default variant key")
	var plain := StatsHistory.new()
	for i in 2:
		var r := DrillResult.new()
		r.drill_id = &"n_back"
		r.config = {"n": 2}
		r.metrics = {"level": 3.0, "accuracy": 0.95}
		r.finished_at_unix = 100 + i
		plain.add(StatsHistory.make_record(r))
	var harder := TrainingPlan.harder_configs(plain)
	assert_true(harder.is_empty(), "n=2 is its own variant, not the default")
	var default_variant := StatsHistory.new()
	for i in 2:
		var r := DrillResult.new()
		r.drill_id = &"reaction_time"
		r.metrics = {"median_rt_ms": 150.0}
		r.finished_at_unix = 100 + i
		default_variant.add(StatsHistory.make_record(r))
		var g := DrillResult.new()
		g.drill_id = &"go_no_go"
		g.config = {"trials": 30, "countdown": true, "adaptive": false}
		g.metrics = {"mean_rt_ms": 200.0, "false_alarm_rate": 0.0, "threshold_ms": -1.0}
		g.finished_at_unix = 100 + i
		default_variant.add(StatsHistory.make_record(g))
	harder = TrainingPlan.harder_configs(default_variant)
	assert_eq(harder.get("go_no_go"), {"adaptive": true})
	assert_false(harder.has("reaction_time"), "reaction time has no harder variant")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var defs: Array[DrillDefinition] = [DrillDefinition.new(&"go_no_go", "T", "D", "s", "CATEGORY_A")]
	var steps := TrainingPlan.suggest(defs, 5, ["CATEGORY_A"] as Array[String], rng, harder)
	assert_eq(steps[0]["config"], {"adaptive": true})
	assert_eq(steps[0]["harder"], true)


func test_weak_categories_week_rotation() -> void:
	var history := StatsHistory.new()
	var now := 1_000_000
	var r := DrillResult.new()
	r.drill_id = &"n_back"
	r.metrics = {"level": 2.0, "accuracy": 0.5}
	r.finished_at_unix = now - 3600
	history.add(StatsHistory.make_record(r))
	var s := DrillResult.new()
	s.drill_id = &"sart"
	s.metrics = {"mean_rt_ms": 300.0, "commission_rate": 0.0}
	s.finished_at_unix = now - 3 * 86400
	history.add(StatsHistory.make_record(s))
	var order := TrainingPlan.weak_categories(_definitions(), history, ORDER, now)
	assert_eq(order, ["CATEGORY_A", "CATEGORY_C", "CATEGORY_B"] as Array[String], "never played A first, C from this week next, B trained today last")


func test_week_summary() -> void:
	var history := StatsHistory.new()
	var now := 2_000_000
	for i in 3:
		var r := DrillResult.new()
		r.drill_id = &"reaction_time"
		r.total_ms = 40000
		r.metrics = {"median_rt_ms": 300.0 + i * 20}
		r.finished_at_unix = now - i * 86400
		history.add(StatsHistory.make_record(r))
	var old := DrillResult.new()
	old.drill_id = &"sart"
	old.total_ms = 60000
	old.metrics = {"mean_rt_ms": 300.0, "commission_rate": 0.0}
	old.finished_at_unix = now - 10 * 86400
	history.add(StatsHistory.make_record(old))
	var week := history.week_summary(now)
	assert_eq(week["runs"], 3)
	assert_eq(week["minutes"], 2)
	assert_eq(week["drills"], 1)
	assert_eq(week["improved"], 1, "the newest reaction run beats the mean of the earlier ones")
