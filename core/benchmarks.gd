## Orientational performance bands (beginner / advanced / elite) per drill,
## based on the maintainer's benchmark table (derived from CANTAB, CogState and
## Z-Health style norms, adjusted to this app's measurement limits). A band is
## evaluated from DrillResult.metrics; an optional accuracy gate stops a fast
## but sloppy run from reaching the elite band.
class_name Benchmarks
extends RefCounted

enum Level { NONE = -1, BEGINNER = 0, ADVANCED = 1, ELITE = 2 }

const LEVEL_KEYS: Array[String] = ["LEVEL_BEGINNER", "LEVEL_ADVANCED", "LEVEL_ELITE"]

## Each entry: metric key, whether lower is better, the elite bound, the
## advanced bound (values beyond it are beginner), an optional "gate" metric
## with an "elite_gate" (max allowed to reach elite) and "beginner_gate"
## (above it the run drops to beginner; "gate_higher" flips both to minimums),
## an optional "floor" under which a reaction time counts as anticipation (no
## band), an optional "config" match and an optional "unit" for the "next
## level from" text. Random input must never reach a band: the playthrough
## prints the band of every run, and a gate is added wherever it does.
const TABLE: Dictionary = {
	"schulte_table": [
		{"config": {"grid_size": 5, "red_black": false, "symbols": "numbers", "test_mode": false}, "metric": "total_ms", "lower": true, "elite": 20000.0, "advanced": 45000.0, "gate": "errors", "elite_gate": 1.0, "beginner_gate": 6.0, "unit": "s"},
		{"config": {"red_black": true, "test_mode": false}, "metric": "total_ms", "lower": true, "elite": 55000.0, "advanced": 120000.0, "gate": "errors", "elite_gate": 0.0, "beginner_gate": 4.0, "unit": "s"},
	],
	"trail_making": [
		{"config": {"trials": 20, "order": 0}, "metric": "total_ms", "lower": true, "elite": 12000.0, "advanced": 28000.0, "unit": "s"},
		{"config": {"trials": 20, "order": 2}, "metric": "total_ms", "lower": true, "elite": 20000.0, "advanced": 50000.0, "unit": "s"},
		{"config": {"trials": 20, "order": 3}, "metric": "total_ms", "lower": true, "elite": 20000.0, "advanced": 50000.0, "unit": "s"},
	],
	"visual_search": [{"config": {"set_size": 64}, "metric": "median_rt_ms", "lower": true, "elite": 420.0, "advanced": 850.0, "unit": "ms"}],
	"sart": [{"metric": "mean_rt_ms", "lower": true, "elite": 290.0, "advanced": 380.0, "floor": 120.0, "gate": "commission_rate", "elite_gate": 0.03, "beginner_gate": 0.15, "unit": "ms"}],
	"posner_cueing": [{"metric": "validity_effect_ms", "lower": true, "elite": 25.0, "advanced": 80.0, "gate": "error_rate", "elite_gate": 0.05, "beginner_gate": 0.2, "unit": "ms"}],
	"object_tracking": [{"metric": "accuracy", "lower": false, "elite": 1.0, "advanced": 0.65, "unit": "%"}],
	"spotlight_search": [{"metric": "ms_per_target", "lower": true, "elite": 900.0, "advanced": 3200.0, "gate": "wrong", "elite_gate": 1.0, "beginner_gate": 6.0, "unit": "s"}],
	"reaction_time": [{"config": {"auditory": false}, "metric": "median_rt_ms", "lower": true, "elite": 180.0, "advanced": 270.0, "floor": 100.0, "gate": "error_rate", "elite_gate": 0.1, "beginner_gate": 0.5, "unit": "ms"}],
	"choice_reaction": [{"metric": "median_rt_ms", "lower": true, "elite": 280.0, "advanced": 420.0, "floor": 150.0, "gate": "error_rate", "elite_gate": 0.05, "beginner_gate": 0.2, "unit": "ms"}],
	"go_no_go": [
		{"config": {"adaptive": false, "auditory": false}, "metric": "mean_rt_ms", "lower": true, "elite": 260.0, "advanced": 380.0, "gate": "false_alarm_rate", "elite_gate": 0.02, "beginner_gate": 0.12, "unit": "ms"},
		{"config": {"adaptive": true, "auditory": false}, "metric": "threshold_ms", "lower": true, "elite": 170.0, "advanced": 350.0, "unit": "ms"},
	],
	"stroop": [{"metric": "interference_ms", "lower": true, "elite": 30.0, "advanced": 140.0, "gate": "error_rate", "elite_gate": 0.05, "beginner_gate": 0.2, "unit": "ms"}],
	"flanker": [{"metric": "interference_ms", "lower": true, "elite": 15.0, "advanced": 80.0, "gate": "error_rate", "elite_gate": 0.05, "beginner_gate": 0.2, "unit": "ms"}],
	"task_switching": [{"metric": "switch_cost_ms", "lower": true, "elite": 60.0, "advanced": 220.0, "gate": "error_rate", "elite_gate": 0.05, "beginner_gate": 0.2, "unit": "ms"}],
	"arithmetic": [{"metric": "ms_per_answer", "lower": true, "elite": 900.0, "advanced": 3000.0, "gate": "error_rate", "elite_gate": 0.05, "beginner_gate": 0.3, "unit": "s"}],
	"sum_pairs": [{"config": {"size": 5, "dynamic": false}, "metric": "ms_per_pair", "lower": true, "elite": 1200.0, "advanced": 3000.0, "gate": "invalid_rate", "elite_gate": 0.02, "beginner_gate": 0.2, "unit": "s"}],
	"anti_saccade": [{"metric": "median_rt_ms", "lower": true, "elite": 240.0, "advanced": 400.0, "gate": "error_rate", "elite_gate": 0.04, "beginner_gate": 0.25, "unit": "ms"}],
	"simon_effect": [{"metric": "interference_ms", "lower": true, "elite": 15.0, "advanced": 75.0, "gate": "error_rate", "elite_gate": 0.05, "beginner_gate": 0.2, "unit": "ms"}],
	"mental_rotation": [{"metric": "median_rt_ms", "lower": true, "elite": 650.0, "advanced": 1800.0, "gate": "accuracy", "elite_gate": 1.0, "beginner_gate": 0.8, "gate_higher": true, "unit": "ms"}],
	"corsi_blocks": [{"metric": "span", "lower": false, "elite": 8.0, "advanced": 6.0, "unit": ""}],
	"digit_span": [
		{"config": {"backward": false}, "metric": "span", "lower": false, "elite": 9.0, "advanced": 7.0, "unit": ""},
		{"config": {"backward": true}, "metric": "span", "lower": false, "elite": 7.0, "advanced": 5.0, "unit": ""},
	],
	"memory_matrix": [{"metric": "max_level", "lower": false, "elite": 12.0, "advanced": 8.0, "unit": ""}],
	"simon": [{"metric": "best_length", "lower": false, "elite": 15.0, "advanced": 10.0, "unit": ""}],
	"rsvp_reading": [{"metric": "wpm", "lower": false, "elite": 800.0, "advanced": 450.0, "gate": "comprehension", "elite_gate": 1.0, "beginner_gate": 1.0, "gate_higher": true, "unit": ""}],
	"number_pyramid": [{"metric": "max_width", "lower": false, "elite": 0.85, "advanced": 0.55, "unit": "%"}],
	"visual_masking": [{"metric": "threshold_ms", "lower": true, "elite": 20.0, "advanced": 85.0, "unit": "ms"}],
	"dynamic_acuity": [{"metric": "best_speed", "lower": false, "elite": 3.2, "advanced": 1.6, "unit": ""}],
	"contrast_sensitivity": [{"metric": "threshold", "lower": true, "elite": 0.02, "advanced": 0.15, "unit": "%"}],
	"peripheral_burst": [{"metric": "detection_rate", "lower": false, "elite": 0.95, "advanced": 0.8, "gate": "centre_error", "elite_gate": 0.0, "beginner_gate": 3.0, "unit": "%"}],
	"peripheral_pattern": [{"metric": "accuracy", "lower": false, "elite": 0.95, "advanced": 0.8, "gate": "centre_error", "elite_gate": 0.0, "beginner_gate": 3.0, "unit": "%"}],
	"temporal_order": [{"metric": "threshold_ms", "lower": true, "elite": 20.0, "advanced": 80.0, "unit": "ms"}],
	"anticipation": [{"metric": "mean_abs_error_ms", "lower": true, "elite": 35.0, "advanced": 180.0, "unit": "ms"}],
	"rhythm_tapping": [{"metric": "jitter_ms", "lower": true, "elite": 9.0, "advanced": 35.0, "unit": "ms"}],
	"pursuit_tracking": [{"metric": "on_target", "lower": false, "elite": 0.94, "advanced": 0.6, "unit": "%"}],
	"compensatory_tracking": [{"metric": "on_target", "lower": false, "elite": 0.94, "advanced": 0.6, "unit": "%"}],
	"time_to_contact": [{"metric": "time_error_ms", "lower": true, "elite": 35.0, "advanced": 160.0, "gate": "position_error", "elite_gate": 0.02, "beginner_gate": 0.1, "unit": "ms"}],
	"brock_string": [{"metric": "jump_rt_ms", "lower": true, "elite": 500.0, "advanced": 1500.0, "gate": "accuracy", "elite_gate": 0.95, "beginner_gate": 0.75, "gate_higher": true, "unit": "ms"}],
	"rotation_3d": [{"metric": "median_rt_ms", "lower": true, "elite": 1300.0, "advanced": 2600.0, "gate": "accuracy", "elite_gate": 0.95, "beginner_gate": 0.75, "gate_higher": true, "unit": "ms"}],
	"dual_task": [{"metric": "interference_percent", "lower": true, "elite": 7.0, "advanced": 35.0, "gate": "arith_accuracy", "gate_higher": true, "elite_gate": 0.9, "beginner_gate": 0.6, "unit": "%p"}],
	"divided_attention": [{"metric": "mean_rt_ms", "lower": true, "elite": 290.0, "advanced": 460.0, "gate": "tracking_mean", "elite_gate": 0.08, "beginner_gate": 0.3, "unit": "ms"}],
}


## Finds the band entry whose config requirements the result satisfies.
static func entry_for(result: DrillResult) -> Dictionary:
	var entries: Array = TABLE.get(String(result.drill_id), [])
	for entry: Dictionary in entries:
		var requirements: Dictionary = entry.get("config", {})
		var matches := true
		for key: String in requirements:
			if not _matches(result.config.get(key), requirements[key]):
				matches = false
				break
		if matches:
			return entry
	return {}


## Compares a config value with a requirement across the types a config can
## hold: a missing flag counts as off, numbers compare as floats (JSON gives
## ints back as floats), and mixed types never match (GDScript raises on
## bool != int).
static func _matches(actual: Variant, required: Variant) -> bool:
	if actual == null:
		return required is bool and not required
	if required is bool:
		return actual is bool and actual == required
	if required is int or required is float:
		if actual is int or actual is float:
			var a: float = actual
			var r: float = required
			return is_equal_approx(a, r)
		return false
	return actual is String and str(actual) == str(required)


## Band bounds for a drill and config whose benchmark metric is [param metric]:
## {"elite", "advanced", "lower"} or empty when none applies.
static func bounds_for(drill_id: StringName, config: Dictionary, metric: String) -> Dictionary:
	var probe := DrillResult.new()
	probe.drill_id = drill_id
	probe.config = config
	var entry := entry_for(probe)
	if entry.is_empty() or entry["metric"] != metric:
		return {}
	return {"elite": entry["elite"], "advanced": entry["advanced"], "lower": entry["lower"]}


## N-back is graded by level and accuracy rather than by one metric.
static func _n_back_level(result: DrillResult) -> Level:
	var n: float = result.metrics.get("level", 0.0)
	var accuracy: float = result.metrics.get("accuracy", 0.0)
	if n >= 3.0 and accuracy >= 0.92:
		return Level.ELITE
	if (n >= 3.0 and accuracy >= 0.7) or (n >= 2.0 and accuracy >= 0.9):
		return Level.ADVANCED
	return Level.BEGINNER


## Returns {"level": Level, "metric": String, "value": float, "next": float, "unit": String}
## or an empty Dictionary when the drill or variant has no benchmark.
static func evaluate(result: DrillResult) -> Dictionary:
	if result.drill_id == &"n_back":
		return {"level": _n_back_level(result), "metric": "level", "value": result.metrics.get("level", 0.0), "next": -1.0, "unit": ""}
	var entry := entry_for(result)
	if entry.is_empty():
		return {}
	var metric: String = entry["metric"]
	var value := MetricCatalog.metric_value(result, metric)
	if is_nan(value):
		return {}
	# A reaction time below the physiological floor is anticipation, not a result.
	if entry.has("floor") and value < entry["floor"]:
		return {}
	var lower: bool = entry["lower"]
	var elite: float = entry["elite"]
	var advanced: float = entry["advanced"]
	var level := Level.BEGINNER
	if lower:
		if value < elite:
			level = Level.ELITE
		elif value <= advanced:
			level = Level.ADVANCED
	else:
		if value >= elite:
			level = Level.ELITE
		elif value >= advanced:
			level = Level.ADVANCED
	if entry.has("gate") and result.metrics.has(entry["gate"]):
		var gate_value: float = result.metrics[entry["gate"]]
		var gate_higher: bool = entry.get("gate_higher", false)
		var passes_elite: bool = gate_value >= entry["elite_gate"] if gate_higher else gate_value <= entry["elite_gate"]
		var fails_beginner: bool = gate_value < entry["beginner_gate"] if gate_higher else gate_value > entry["beginner_gate"]
		if fails_beginner:
			level = Level.BEGINNER
		elif level == Level.ELITE and not passes_elite:
			level = Level.ADVANCED
	var next := -1.0
	if level == Level.BEGINNER:
		next = advanced
	elif level == Level.ADVANCED:
		next = elite
	return {"level": level, "metric": metric, "value": value, "next": next, "unit": entry.get("unit", "")}


## Formats a benchmark bound in the entry's unit.
static func format_bound(value: float, unit: String) -> String:
	match unit:
		"s":
			return Format.seconds(roundi(value))
		"ms":
			return Format.millis(value)
		"%":
			return Format.percent(value)
		"%p":
			return "%d %%" % roundi(value)
	return "%d" % roundi(value) if value == floorf(value) else "%.1f" % value
