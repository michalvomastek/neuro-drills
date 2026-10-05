## Which number of a result is "the" number of each drill, how a run's variant
## is identified, and the per-run derived statistics (variability, fatigue)
## that the history and the progress screen share.
class_name MetricCatalog
extends RefCounted

## Primary metric per drill: key into DrillResult.metrics, whether lower is
## better and the unit used by Benchmarks.format_bound.
const PRIMARY: Dictionary = {
	"schulte_table": {"metric": "total_ms", "lower": true, "unit": "s"},
	"trail_making": {"metric": "total_ms", "lower": true, "unit": "s"},
	"visual_search": {"metric": "median_rt_ms", "lower": true, "unit": "ms"},
	"sart": {"metric": "mean_rt_ms", "lower": true, "unit": "ms"},
	"posner_cueing": {"metric": "validity_effect_ms", "lower": true, "unit": "ms"},
	"object_tracking": {"metric": "accuracy", "lower": false, "unit": "%"},
	"spotlight_search": {"metric": "ms_per_target", "lower": true, "unit": "s"},
	"reaction_time": {"metric": "median_rt_ms", "lower": true, "unit": "ms"},
	"choice_reaction": {"metric": "median_rt_ms", "lower": true, "unit": "ms"},
	"go_no_go": {"metric": "mean_rt_ms", "lower": true, "unit": "ms"},
	"stroop": {"metric": "interference_ms", "lower": true, "unit": "ms"},
	"flanker": {"metric": "interference_ms", "lower": true, "unit": "ms"},
	"task_switching": {"metric": "switch_cost_ms", "lower": true, "unit": "ms"},
	"arithmetic": {"metric": "ms_per_answer", "lower": true, "unit": "s"},
	"anti_saccade": {"metric": "median_rt_ms", "lower": true, "unit": "ms"},
	"simon_effect": {"metric": "interference_ms", "lower": true, "unit": "ms"},
	"mental_rotation": {"metric": "median_rt_ms", "lower": true, "unit": "ms"},
	"n_back": {"metric": "accuracy", "lower": false, "unit": "%"},
	"corsi_blocks": {"metric": "span", "lower": false, "unit": ""},
	"digit_span": {"metric": "span", "lower": false, "unit": ""},
	"memory_matrix": {"metric": "max_level", "lower": false, "unit": ""},
	"simon": {"metric": "best_length", "lower": false, "unit": ""},
	"rsvp_reading": {"metric": "wpm", "lower": false, "unit": ""},
	"number_pyramid": {"metric": "max_width", "lower": false, "unit": "%"},
	"flash_number": {"metric": "digits", "lower": false, "unit": ""},
	"visual_masking": {"metric": "threshold_ms", "lower": true, "unit": "ms"},
	"dynamic_acuity": {"metric": "best_speed", "lower": false, "unit": ""},
	"contrast_sensitivity": {"metric": "threshold", "lower": true, "unit": "%"},
	"okn_stripes": {"metric": "detection_rate", "lower": false, "unit": "%"},
	"peripheral_burst": {"metric": "detection_rate", "lower": false, "unit": "%"},
	"peripheral_pattern": {"metric": "accuracy", "lower": false, "unit": "%"},
	"peripheral_reading": {"metric": "letters_error", "lower": true, "unit": ""},
	"temporal_order": {"metric": "threshold_ms", "lower": true, "unit": "ms"},
	"anticipation": {"metric": "mean_abs_error_ms", "lower": true, "unit": "ms"},
	"rhythm_tapping": {"metric": "jitter_ms", "lower": true, "unit": "ms"},
	"pursuit_tracking": {"metric": "on_target", "lower": false, "unit": "%"},
	"compensatory_tracking": {"metric": "on_target", "lower": false, "unit": "%"},
	"time_to_contact": {"metric": "time_error_ms", "lower": true, "unit": "ms"},
	"brock_string": {"metric": "jump_rt_ms", "lower": true, "unit": "ms"},
	"rotation_3d": {"metric": "median_rt_ms", "lower": true, "unit": "ms"},
	"optic_flow": {"metric": "evasion_rate", "lower": false, "unit": "%"},
	"dual_task": {"metric": "interference_percent", "lower": true, "unit": "%p"},
	"divided_attention": {"metric": "mean_rt_ms", "lower": true, "unit": "ms"},
}

## Config keys that change how a run looks but not what it measures; they do
## not split the history into separate variants.
const COSMETIC_KEYS: Array[String] = [
	"countdown", "show_timer", "show_errors", "show_next", "show_next_target",
	"fixation_dot", "dim_found", "highlight_correct",
]
## Drills measured by an adaptive staircase: one run is noisy, so the results
## and progress screens also show the mean of the best 3 runs of the last 5 days.
const THRESHOLD_DRILLS: Array[String] = ["visual_masking", "contrast_sensitivity", "temporal_order", "dynamic_acuity", "flash_number"]
## Drills whose primary metric is a total, so the trial count is part of the variant.
const TRIALS_MATTER: Array[String] = ["trail_making"]

## Per-trial time lists in DrillResult.details, in order of preference.
const TIME_LIST_KEYS: Array[String] = ["times_ms", "hit_times_ms", "go_times_ms", "first_move_ms"]
## Lists of cumulative timestamps: consecutive differences are the per-item times.
const CUMULATIVE_LIST_KEYS: Array[String] = ["found_at_ms"]
const MIN_FATIGUE_SAMPLES := 9
## Metrics that are only meaningful above zero: a staircase that found no
## threshold reports -1, and a reaction drill without a single valid response
## reports 0 ms. Signed differences (interference, switch cost) may be negative.
const POSITIVE_METRICS: Array[String] = ["median_rt_ms", "mean_rt_ms", "jump_rt_ms", "ms_per_target", "ms_per_answer", "threshold_ms", "total_ms"]


static func primary_of(drill_id: StringName) -> Dictionary:
	return PRIMARY.get(String(drill_id), {})


## Value of the primary metric, or NAN when the result does not carry a usable one.
static func primary_value(result: DrillResult) -> float:
	var primary := primary_of(result.drill_id)
	if primary.is_empty():
		return NAN
	var metric: String = primary["metric"]
	return metric_value(result, metric)


## A metric of the result, or NAN when it is missing or not usable (see POSITIVE_METRICS).
static func metric_value(result: DrillResult, metric: String) -> float:
	if not result.metrics.has(metric):
		return NAN
	var value: float = result.metrics[metric]
	if POSITIVE_METRICS.has(metric) and value <= 0.0:
		return NAN
	return value


## Stable identifier of a drill variant: the drill id plus every config key
## that affects comparability, sorted, e.g. "schulte_table|grid_size=5|symbols=numbers".
## Switched-off options (false) are left out, so they read as the default.
static func variant_key(drill_id: StringName, config: Dictionary) -> String:
	var keys: Array[String] = []
	for name: String in config:
		if COSMETIC_KEYS.has(name):
			continue
		if name == "trials" and not TRIALS_MATTER.has(String(drill_id)):
			continue
		if config[name] is bool and not config[name]:
			continue
		keys.append(name)
	keys.sort()
	var parts: Array[String] = [String(drill_id)]
	for name in keys:
		parts.append("%s=%s" % [name, _value_text(config[name])])
	return "|".join(parts)


## Translation key per option: a plain key for switches, a format with one
## "%s" for values. Options not listed fall back to "key value".
const OPTION_LABELS: Dictionary = {
	"grid_size": "VARIANT_GRID", "size": "VARIANT_GRID", "trials": "VARIANT_TRIALS",
	"n": "VARIANT_N_BACK", "bpm": "VARIANT_BPM", "duration_s": "VARIANT_DURATION",
	"radius": "VARIANT_RADIUS", "set_size": "VARIANT_SET_SIZE", "wpm": "VARIANT_WPM",
	"speed": "VARIANT_SPEED", "red_black": "VARIANT_RED_BLACK", "reverse": "VARIANT_REVERSE",
	"shuffle_after_click": "VARIANT_SHUFFLE", "test_mode": "VARIANT_TEST_MODE",
	"backward": "VARIANT_BACKWARD", "adaptive": "VARIANT_ADAPTIVE", "part_b": "TRAIL_OPT_PART_B",
	"moving": "TRAIL_OPT_MOVING", "auditory": "VARIANT_AUDITORY",
}
## Translation key per enumerated value, keyed by "option=value".
const VALUE_LABELS: Dictionary = {
	"symbols=numbers": "VARIANT_NUMBERS", "symbols=letters": "VARIANT_LETTERS",
	"order=0": "TRAIL_ORDER_NUM_ASC", "order=1": "TRAIL_ORDER_NUM_DESC",
	"order=2": "TRAIL_ORDER_NUM_ASC_LET_DESC", "order=3": "TRAIL_ORDER_NUM_DESC_LET_ASC",
}


## Translated, human readable form of the variant part of the key, e.g.
## "7×7 · červeno-černá"; empty for the default variant.
static func variant_label(variant: String) -> String:
	var parts := variant.split("|")
	var labels: Array[String] = []
	for i in range(1, parts.size()):
		labels.append(_option_label(parts[i]))
	return " · ".join(labels)


static func _option_label(pair_text: String) -> String:
	var pair := pair_text.split("=")
	var option := pair[0]
	var value := pair[1] if pair.size() > 1 else ""
	if VALUE_LABELS.has(pair_text):
		var value_key: String = VALUE_LABELS[pair_text]
		return TranslationServer.translate(value_key)
	if OPTION_LABELS.has(option):
		var option_key: String = OPTION_LABELS[option]
		var text := TranslationServer.translate(option_key)
		if value == "true" or value.is_empty():
			return text
		if text.contains("%s"):
			return text % value if text.count("%s") == 1 else text % [value, value]
		return "%s %s" % [text, value]
	return option.replace("_", " ") if value == "true" else "%s %s" % [option.replace("_", " "), value]


static func drill_id_of(variant: String) -> StringName:
	return StringName(variant.get_slice("|", 0))


static func _value_text(value: Variant) -> String:
	if value is float:
		var f: float = value
		return str(int(f)) if f == floorf(f) else "%.2f" % f
	return str(value)


## Per-trial times a result carries, or an empty array.
static func trial_times(details: Dictionary) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for key in TIME_LIST_KEYS:
		if details.has(key) and details[key] is Array:
			var list: Array = details[key]
			for v: float in list:
				out.append(v)
			return out
	for key in CUMULATIVE_LIST_KEYS:
		if details.has(key) and details[key] is Array:
			var list: Array = details[key]
			var previous := 0.0
			for at: float in list:
				out.append(at - previous)
				previous = at
			return out
	return out


## Standard deviation of the per-trial times, or NAN without enough data.
static func variability_ms(details: Dictionary) -> float:
	var times := trial_times(details)
	if times.size() < 3:
		return NAN
	var mean := 0.0
	for t in times:
		mean += t
	mean /= times.size()
	var variance := 0.0
	for t in times:
		variance += (t - mean) * (t - mean)
	return sqrt(variance / times.size())


## Mean of the last third of the per-trial times divided by the mean of the
## first third: 1.0 means no change, 1.2 means 20 % slower at the end. NAN
## without enough data.
static func fatigue_index(details: Dictionary) -> float:
	var times := trial_times(details)
	if times.size() < MIN_FATIGUE_SAMPLES:
		return NAN
	var third := times.size() / 3
	var first := 0.0
	var last := 0.0
	for i in third:
		first += times[i]
		last += times[times.size() - 1 - i]
	if first <= 0.0:
		return NAN
	return last / first


## Help shown on a setup panel: what the drill measures, which direction is
## better and, when a benchmark applies to [param config], the band bounds.
static func help_text(drill_id: StringName, config: Dictionary) -> String:
	var primary := primary_of(drill_id)
	if primary.is_empty():
		return ""
	var metric: String = primary["metric"]
	var unit: String = primary["unit"]
	var lower: bool = primary["lower"]
	var name := TranslationServer.translate("METRIC_" + metric.to_upper())
	if not unit.is_empty():
		name += " (%s)" % unit
	var text := TranslationServer.translate("HELP_MEASURES_LOWER" if lower else "HELP_MEASURES_HIGHER") % name
	var bounds := Benchmarks.bounds_for(drill_id, config, metric)
	if not bounds.is_empty():
		var advanced: float = bounds["advanced"]
		var elite: float = bounds["elite"]
		text += "\n" + TranslationServer.translate("HELP_BANDS") % [format_value(advanced, unit), format_value(elite, unit)]
	return text


## Formats a primary-metric value in its unit.
static func format_value(value: float, unit: String) -> String:
	return Benchmarks.format_bound(value, unit)


## Signed difference in the unit, e.g. "−12 ms" or "+1".
static func format_delta(delta: float, unit: String) -> String:
	var sign := "−" if delta < 0.0 else "+"
	var magnitude := absf(delta)
	if unit == "%" or unit == "%p":
		return "%s%d %%" % [sign, roundi(magnitude * (100.0 if unit == "%" else 1.0))]
	if unit == "s":
		return sign + Format.seconds(roundi(magnitude))
	if unit == "ms":
		return sign + Format.millis(magnitude)
	return "%s%d" % [sign, roundi(magnitude)] if magnitude == floorf(magnitude) else "%s%.1f" % [sign, magnitude]
