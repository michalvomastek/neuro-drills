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


## Categories ordered weakest first: unplayed categories lead, then the
## ascending mean of the last level reached in each drill of the category.
static func weak_categories(definitions: Array[DrillDefinition], history: StatsHistory, order: Array[String]) -> Array[String]:
	var last_level: Dictionary = {}
	for variant in history.variants():
		var overview := history.overview(variant)
		if overview.is_empty():
			continue
		var level: int = overview["last_level"]
		if level < 0:
			continue
		var drill_id := String(MetricCatalog.drill_id_of(variant))
		var known: int = last_level.get(drill_id, -1)
		last_level[drill_id] = maxi(known, level)
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
		score[category] = -1.0 if count == 0 else total / count
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
static func suggest(definitions: Array[DrillDefinition], minutes: int, category_order: Array[String], rng: RandomNumberGenerator) -> Array[Dictionary]:
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
		steps.append(make_step(pick.id))
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
