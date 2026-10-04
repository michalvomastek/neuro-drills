## Corsi block-tapping: blocks light up in a sequence that must be repeated.
class_name CorsiLogic
extends RefCounted

const BLOCK_COUNT := 9
const START_LENGTH := 2
const MAX_LENGTH := 9
## Irregular block layout in board-relative coordinates (top-left corners).
const LAYOUT: Array[Vector2] = [
	Vector2(0.08, 0.06), Vector2(0.46, 0.02), Vector2(0.80, 0.12),
	Vector2(0.22, 0.34), Vector2(0.58, 0.30), Vector2(0.02, 0.60),
	Vector2(0.38, 0.62), Vector2(0.74, 0.56), Vector2(0.56, 0.84),
]
const BLOCK_SIZE := 0.14

var tracker := SpanTracker.new(START_LENGTH, MAX_LENGTH)
var sequence: Array[int] = []
var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


## Draws a new sequence of the current length without immediate repeats.
func new_sequence() -> Array[int]:
	sequence.clear()
	for i in tracker.length:
		var block := _rng.randi_range(0, BLOCK_COUNT - 1)
		if not sequence.is_empty() and block == sequence[sequence.size() - 1]:
			block = (block + 1 + _rng.randi_range(0, BLOCK_COUNT - 2)) % BLOCK_COUNT
		sequence.append(block)
	return sequence


func check(answer: Array[int]) -> bool:
	var success := answer == sequence
	tracker.record(success)
	return success


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.error_count = tracker.rounds - tracker.correct_rounds
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["RESULT_SPAN", str(tracker.span)]),
		PackedStringArray(["RESULT_ROUNDS", "%d / %d" % [tracker.correct_rounds, tracker.rounds]]),
	]
	result.details = {"span": tracker.span, "rounds": tracker.rounds}
	result.metrics = {"span": float(tracker.span)}
	return result
