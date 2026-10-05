## Builds and stores training sessions: an ordered list of steps, each a
## drill id with a config, sized to a time budget. Pure logic; StatsStore
## persists the saved plans and SceneRouter runs a session.
class_name TrainingPlan
extends RefCounted

## Typical length of one run with the default settings, in seconds, including
## the countdown. Rough on purpose: the plan only needs the right ballpark.
const DURATION_S: Dictionary = {
	"schulte_table": 45, "reaction_time": 30, "choice_reaction": 45, "go_no_go": 60,
	"stroop": 50, "flanker": 50, "n_back": 70, "corsi_blocks": 60, "digit_span": 60,
	"memory_matrix": 60, "simon": 60, "trail_making": 40, "visual_search": 40, "sart": 80,
	"task_switching": 60, "rsvp_reading": 60, "number_pyramid": 50, "flash_number": 50,
	"arithmetic": 65, "anti_saccade": 45, "simon_effect": 50, "posner_cueing": 50,
	"peripheral_burst": 60, "visual_masking": 70, "temporal_order": 60, "object_tracking": 70,
	"anticipation": 40, "compensatory_tracking": 35, "pursuit_tracking": 35, "dynamic_acuity": 50,
	"rhythm_tapping": 40, "mental_rotation": 50, "spotlight_search": 60, "contrast_sensitivity": 60,
	"okn_stripes": 40, "time_to_contact": 40, "brock_string": 50, "rotation_3d": 60,
	"optic_flow": 40, "dual_task": 60, "divided_attention": 60, "peripheral_pattern": 50,
	"peripheral_reading": 40,
}
const DEFAULT_DURATION_S := 60
## Harder settings offered once the default variant was played at the elite
## level twice in a row (adaptive difficulty).
const HARDER: Dictionary = {
	"schulte_table": {"grid_size": 7}, "n_back": {"n": 3}, "visual_search": {"set_size": 64},
	"memory_matrix": {"size": 6}, "spotlight_search": {"radius": 8}, "okn_stripes": {"speed": 3},
	"pursuit_tracking": {"speed": 3}, "rsvp_reading": {"wpm": 500}, "trail_making": {"order": 2},
	"digit_span": {"backward": true}, "go_no_go": {"adaptive": true},
}
const ELITE_STREAK_FOR_HARDER := 2
const DAY_S := 86400
## Results screen, breathing, tapping Next: counted once per step.
const STEP_OVERHEAD_S := 12
const MIN_MINUTES := 1
const MAX_MINUTES := 30


static func estimate_seconds(drill_id: StringName) -> int:
	var seconds: int = DURATION_S.get(String(drill_id), DEFAULT_DURATION_S)
	return seconds + STEP_OVERHEAD_S


static func total_seconds(steps: Array[Dictionary]) -> int:
	var total := 0
	for step in steps:
		var id: String = step["drill_id"]
		total += estimate_seconds(StringName(id))
	return total


static func make_step(drill_id: StringName, config: Dictionary = {}) -> Dictionary:
	return {"drill_id": String(drill_id), "config": config.duplicate()}


## Drills whose last ELITE_STREAK_FOR_HARDER runs (of any variant except the
## harder one itself) reached the elite band, mapped to the harder config.
static func harder_configs(history: StatsHistory) -> Dictionary:
	var out: Dictionary = {}
	for drill_id: String in HARDER:
		var harder_config: Dictionary = HARDER[drill_id]
		var runs: Array[Dictionary] = []
		for variant in history.variants():
			if MetricCatalog.drill_id_of(variant) != StringName(drill_id):
				continue
			for run in history.for_variant(variant):
				var run_config: Dictionary = run.get("config", {})
				if not _satisfies(run_config, harder_config):
					runs.append(run)
		runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var at_a: int = a["at"]
			var at_b: int = b["at"]
			return at_a < at_b)
		if runs.size() < ELITE_STREAK_FOR_HARDER:
			continue
		var all_elite := true
		for i in range(runs.size() - ELITE_STREAK_FOR_HARDER, runs.size()):
			var level: int = runs[i]["level"]
			if level != Benchmarks.Level.ELITE:
				all_elite = false
		if all_elite:
			var config: Dictionary = HARDER[drill_id]
			out[drill_id] = config.duplicate()
	return out


## True when [param config] already has every value of [param harder] (the
## run was the harder variant, whatever else its key carries, e.g. trials).
static func _satisfies(config: Dictionary, harder: Dictionary) -> bool:
	for key: String in harder:
		if not config.has(key) or MetricCatalog._value_text(config[key]) != MetricCatalog._value_text(harder[key]):
			return false
	return true


## Categories ordered by training need: categories not trained in the last
## week lead (so a week covers all of them), then the ascending mean of the
## last level reached in each drill, and categories already trained today go
## last. [param now_unix] is the current time; 0 means "ignore recency".
static func weak_categories(definitions: Array[DrillDefinition], history: StatsHistory, order: Array[String], now_unix: int = 0) -> Array[String]:
	var category_of: Dictionary = {}
	for definition in definitions:
		category_of[String(definition.id)] = definition.category_key
	var last_level: Dictionary = {}
	var last_played: Dictionary = {}
	for variant in history.variants():
		var overview := history.overview(variant)
		if overview.is_empty():
			continue
		var drill_id := String(MetricCatalog.drill_id_of(variant))
		var level: int = overview["last_level"]
		if level >= 0:
			var known: int = last_level.get(drill_id, -1)
			last_level[drill_id] = maxi(known, level)
		var category: String = category_of.get(drill_id, "")
		var at: int = overview["last_at"]
		var known_at: int = last_played.get(category, 0)
		last_played[category] = maxi(known_at, at)
	var score: Dictionary = {}
	for category in order:
		var total := 0.0
		var count := 0
		for definition in definitions:
			if definition.category_key != category:
				continue
			if last_level.has(String(definition.id)):
				var level: int = last_level[String(definition.id)]
				total += level
				count += 1
		var level_score := -1.0 if count == 0 else total / count
		var played_at: int = last_played.get(category, 0)
		var rank := 1.0
		if now_unix > 0 and played_at > 0:
			if now_unix - played_at < DAY_S:
				rank = 2.0
			elif now_unix - played_at < 7 * DAY_S:
				rank = 1.0
			else:
				rank = 0.0
		elif now_unix > 0:
			rank = 0.0
		score[category] = rank * 10.0 + level_score
	var out := order.duplicate()
	out.sort_custom(func(a: String, b: String) -> bool:
		var sa: float = score[a]
		var sb: float = score[b]
		if sa == sb:
			return order.find(a) < order.find(b)
		return sa < sb)
	return out


## Proposes steps for [param minutes]: walks the categories in [param category_order]
## round robin, takes one unused drill from each (random, seeded by [param rng])
## and stops when the next step would overrun the budget. Always returns at
## least one step when any drill exists.
static func suggest(definitions: Array[DrillDefinition], minutes: int, category_order: Array[String], rng: RandomNumberGenerator, harder: Dictionary = {}) -> Array[Dictionary]:
	var budget := clampi(minutes, MIN_MINUTES, MAX_MINUTES) * 60
	var pools: Dictionary = {}
	for category in category_order:
		var pool: Array[DrillDefinition] = []
		for definition in definitions:
			if definition.category_key == category:
				pool.append(definition)
		if not pool.is_empty():
			pools[category] = pool
	var steps: Array[Dictionary] = []
	var used := 0
	var categories: Array[String] = []
	for category in category_order:
		if pools.has(category):
			categories.append(category)
	if categories.is_empty():
		return steps
	var index := 0
	var skipped_in_row := 0
	while skipped_in_row < categories.size():
		var category := categories[index % categories.size()]
		index += 1
		var pool: Array[DrillDefinition] = pools[category]
		var fitting: Array[DrillDefinition] = []
		for definition in pool:
			if used + estimate_seconds(definition.id) <= budget or steps.is_empty():
				fitting.append(definition)
		if fitting.is_empty():
			skipped_in_row += 1
			continue
		skipped_in_row = 0
		var pick := fitting[rng.randi_range(0, fitting.size() - 1)]
		pool.erase(pick)
		var config: Dictionary = harder.get(String(pick.id), {})
		var step := make_step(pick.id, config)
		if not config.is_empty():
			step["harder"] = true
		steps.append(step)
		used += estimate_seconds(pick.id)
		if pool.is_empty():
			pools.erase(category)
			categories.erase(category)
			if categories.is_empty():
				break
	return steps


## Saved plans: {"name": String, "steps": Array[Dictionary]}.
static func serialize_plans(plans: Array[Dictionary]) -> String:
	return JSON.stringify(plans)


static func parse_plans(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Array:
		return out
	var list: Array = parsed
	for item: Variant in list:
		if not item is Dictionary:
			continue
		var plan: Dictionary = item
		if not plan.has("name") or not plan.get("steps") is Array:
			continue
		var steps: Array[Dictionary] = []
		var raw_steps: Array = plan["steps"]
		for raw: Variant in raw_steps:
			if raw is Dictionary and (raw as Dictionary).has("drill_id"):
				var step: Dictionary = raw
				if not step.get("config") is Dictionary:
					step["config"] = {}
				steps.append(step)
		if not steps.is_empty():
			out.append({"name": str(plan["name"]), "steps": steps})
	return out
