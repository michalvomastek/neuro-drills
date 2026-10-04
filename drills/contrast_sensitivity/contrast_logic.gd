## Contrast sensitivity: a Gabor patch at one of four orientations; contrast
## falls after each correct answer towards the visibility threshold.
class_name ContrastLogic
extends RefCounted

const ORIENTATIONS_DEG: Array[float] = [0.0, 45.0, 90.0, 135.0]
const START := 0.4
const MIN := 0.01
const MAX := 1.0
const STEP_DOWN := 0.04
const STEP_UP := 0.08

var trials: int
var staircase := Staircase.new(START, MIN, MAX, STEP_DOWN, STEP_UP)
var orientation_index: int = 0
var current: int = 0
var correct_count: int = 0
var _rng: RandomNumberGenerator


func _init(p_trials: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	_rng = rng


func contrast() -> float:
	return staircase.value


func new_trial() -> void:
	orientation_index = _rng.randi_range(0, ORIENTATIONS_DEG.size() - 1)


func orientation_radians() -> float:
	return deg_to_rad(ORIENTATIONS_DEG[orientation_index])


func answer(index: int) -> bool:
	var correct := index == orientation_index
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
	result.error_count = trials - correct_count
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	var threshold := staircase.best if staircase.has_threshold() else 1.0
	result.summary_rows = [
		PackedStringArray(["CONTRAST_THRESHOLD", Format.percent(threshold)]),
		PackedStringArray(["CONTRAST_SENSITIVITY", "%.0f" % (1.0 / threshold)]),
		PackedStringArray(["RESULT_ACCURACY", Format.percent(float(correct_count) / trials if trials > 0 else 0.0)]),
	]
	result.details = {"threshold": threshold, "correct": correct_count}
	result.metrics = {"threshold": threshold}
	return result
