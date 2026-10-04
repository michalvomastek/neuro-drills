## Simple reaction time: random wait, go signal, one response per trial.
class_name ReactionLogic
extends RefCounted

const MIN_DELAY_MS := 1500
const MAX_DELAY_MS := 4000

var trials: int
var stats := ReactionStats.new()
var premature_count: int = 0
var _rng: RandomNumberGenerator


func _init(p_trials: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	_rng = rng


func next_delay_ms() -> int:
	return _rng.randi_range(MIN_DELAY_MS, MAX_DELAY_MS)


func record_reaction(rt_ms: int) -> void:
	stats.add(rt_ms)


func record_premature() -> void:
	premature_count += 1


func is_done() -> bool:
	return stats.count() >= trials


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(stats.median())
	result.error_count = premature_count
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["RESULT_MEDIAN_RT", Format.millis(stats.median())]),
		PackedStringArray(["RESULT_MEAN_RT", Format.millis(stats.mean())]),
		PackedStringArray(["RESULT_BEST_RT", Format.millis(stats.best())]),
		PackedStringArray(["RESULT_PREMATURE", str(premature_count)]),
	]
	result.details = {"times_ms": stats.times_ms.duplicate(), "premature": premature_count}
	return result
