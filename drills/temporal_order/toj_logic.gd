## Temporal order judgment: two discs appear a few milliseconds apart; which
## came first? The gap adapts towards the smallest one still judged correctly.
class_name TojLogic
extends RefCounted

const START_MS := 120.0
## One frame at 60 Hz; the drill cannot resolve less than the refresh interval.
const MIN_MS := 16.0
const MAX_MS := 400.0
const STEP_DOWN_MS := 12.0
const STEP_UP_MS := 24.0
const HOLD_MS := 400

var trials: int
var staircase := Staircase.new(START_MS, MIN_MS, MAX_MS, STEP_DOWN_MS, STEP_UP_MS)
var first_side: int = 0
var current: int = 0
var correct_count: int = 0
var _rng: RandomNumberGenerator


func _init(p_trials: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	_rng = rng


func soa_ms() -> float:
	return staircase.value


func new_trial() -> void:
	first_side = _rng.randi_range(0, 1)


func answer(side: int) -> bool:
	var correct := side == first_side
	if correct:
		correct_count += 1
	staircase.record(correct)
	current += 1
	return correct


func is_done() -> bool:
	return current >= trials


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(staircase.best) if staircase.has_threshold() else 0
	result.error_count = trials - correct_count
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["TOJ_THRESHOLD", Format.millis(staircase.best) if staircase.has_threshold() else "–"]),
		PackedStringArray(["RESULT_ACCURACY", Format.percent(float(correct_count) / trials if trials > 0 else 0.0)]),
		PackedStringArray(["STAIRCASE_FINAL", Format.millis(staircase.value)]),
	]
	result.details = {"threshold_ms": staircase.best if staircase.has_threshold() else -1, "correct": correct_count}
	result.metrics = {"threshold_ms": staircase.best if staircase.has_threshold() else -1.0}
	return result
