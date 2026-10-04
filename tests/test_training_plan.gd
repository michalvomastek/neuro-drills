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
