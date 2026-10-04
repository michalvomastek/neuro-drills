## Dynamic visual acuity: a Landolt C flies across the screen; report where
## its gap pointed. Speed rises after a correct answer.
class_name AcuityLogic
extends RefCounted

enum Gap { UP, RIGHT, DOWN, LEFT }

const START_SPEED := 0.6
const MIN_SPEED := 0.3
const MAX_SPEED := 3.0
const STEP_UP := 0.15
const STEP_DOWN := 0.3

var trials: int
## Speed in stage widths per second, driven by a staircase that goes "harder" on correct.
var staircase := Staircase.new(-START_SPEED, -MAX_SPEED, -MIN_SPEED, STEP_UP, STEP_DOWN)
var gap: Gap = Gap.UP
var direction: int = 1
var current: int = 0
var correct_count: int = 0
var _rng: RandomNumberGenerator


func _init(p_trials: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	_rng = rng


func speed() -> float:
	return -staircase.value


func best_speed() -> float:
	return -staircase.best if staircase.has_threshold() else 0.0


func new_trial() -> void:
	gap = _rng.randi_range(0, 3) as Gap
	direction = 1 if _rng.randi_range(0, 1) == 0 else -1


## Seconds the ring needs to cross the stage (plus margins).
func flight_seconds() -> float:
	return 1.2 / speed()


func answer(chosen: Gap) -> bool:
	var correct := chosen == gap
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
	result.summary_rows = [
		PackedStringArray(["ACUITY_BEST_SPEED", "%.2f" % best_speed()]),
		PackedStringArray(["RESULT_ACCURACY", Format.percent(float(correct_count) / trials if trials > 0 else 0.0)]),
		PackedStringArray(["STAIRCASE_FINAL", "%.2f" % speed()]),
	]
	result.details = {"best_speed": best_speed(), "correct": correct_count}
	return result
