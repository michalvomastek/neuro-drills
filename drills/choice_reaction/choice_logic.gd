## Two-choice reaction: a side is cued and the matching side must be pressed,
## or the opposite one when [member mirrored] is set (anti-saccade).
class_name ChoiceLogic
extends RefCounted

const MIN_DELAY_MS := 800
const MAX_DELAY_MS := 1800

var trials: int
var mirrored: bool
## Cued side per trial: 0 = left, 1 = right.
var sides: Array[int] = []
var current: int = 0
var stats := ReactionStats.new()
var wrong_count: int = 0
var _rng: RandomNumberGenerator


func _init(p_trials: int, rng: RandomNumberGenerator, p_mirrored: bool = false) -> void:
	trials = p_trials
	mirrored = p_mirrored
	_rng = rng
	for i in trials:
		sides.append(_rng.randi_range(0, 1))


func next_delay_ms() -> int:
	return _rng.randi_range(MIN_DELAY_MS, MAX_DELAY_MS)


func current_side() -> int:
	return sides[current]


## The side that has to be pressed for the current trial.
func correct_side() -> int:
	return 1 - sides[current] if mirrored else sides[current]


## Records the answer for the current trial and advances; returns whether it was correct.
func record_response(side: int, rt_ms: int) -> bool:
	var correct := side == correct_side()
	if correct:
		stats.add(rt_ms)
	else:
		wrong_count += 1
	current += 1
	return correct


func is_done() -> bool:
	return current >= trials


func accuracy() -> float:
	return float(trials - wrong_count) / trials if trials > 0 else 0.0


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(stats.median())
	result.error_count = wrong_count
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["RESULT_MEDIAN_RT", Format.millis(stats.median())]),
		PackedStringArray(["RESULT_MEAN_RT", Format.millis(stats.mean())]),
		PackedStringArray(["RESULT_ACCURACY", Format.percent(accuracy())]),
		PackedStringArray(["RESULT_WRONG", str(wrong_count)]),
	]
	result.details = {"times_ms": stats.times_ms.duplicate(), "wrong": wrong_count}
	result.metrics = {"median_rt_ms": stats.median(), "error_rate": 1.0 - accuracy()}
	return result
