## Number pyramid: two digits flash left and right of the centre; the distance
## grows after a correct answer and shrinks after a wrong one.
class_name PyramidLogic
extends RefCounted

const START_DISTANCE := 0.12
const MIN_DISTANCE := 0.06
const MAX_DISTANCE := 0.48
const STEP := 0.04
const FLASH_MS := 300

var rounds: int
var distance: float = START_DISTANCE
var max_distance: float = 0.0
var rounds_done: int = 0
var rounds_correct: int = 0
var left: int = 0
var right: int = 0
var _rng: RandomNumberGenerator


func _init(p_rounds: int, rng: RandomNumberGenerator) -> void:
	rounds = p_rounds
	_rng = rng


func new_round() -> void:
	left = _rng.randi_range(0, 9)
	right = _rng.randi_range(0, 9)
	if right == left:
		right = (right + 1 + _rng.randi_range(0, 8)) % 10


func check(answer_left: int, answer_right: int) -> bool:
	var correct := answer_left == left and answer_right == right
	rounds_done += 1
	if correct:
		rounds_correct += 1
		max_distance = maxf(max_distance, distance)
		distance = minf(MAX_DISTANCE, distance + STEP)
	else:
		distance = maxf(MIN_DISTANCE, distance - STEP)
	return correct


func is_done() -> bool:
	return rounds_done >= rounds


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.error_count = rounds_done - rounds_correct
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["PYRAMID_MAX_SPAN", Format.percent(max_distance * 2.0)]),
		PackedStringArray(["RESULT_ROUNDS", "%d / %d" % [rounds_correct, rounds_done]]),
	]
	result.details = {"max_distance": max_distance, "rounds_correct": rounds_correct}
	result.metrics = {"max_width": max_distance * 2.0}
	return result
