## Digit span: digits are shown one by one and typed back, forward or backward.
class_name DigitSpanLogic
extends RefCounted

const START_LENGTH := 3
const MAX_LENGTH := 12

var backward: bool
var tracker := SpanTracker.new(START_LENGTH, MAX_LENGTH)
var sequence: Array[int] = []
var _rng: RandomNumberGenerator


func _init(p_backward: bool, rng: RandomNumberGenerator) -> void:
	backward = p_backward
	_rng = rng


func new_sequence() -> Array[int]:
	sequence.clear()
	for i in tracker.length:
		var digit := _rng.randi_range(0, 9)
		if not sequence.is_empty() and digit == sequence[sequence.size() - 1]:
			digit = (digit + 1 + _rng.randi_range(0, 8)) % 10
		sequence.append(digit)
	return sequence


## The digits the player has to enter for the current sequence.
func expected() -> Array[int]:
	if not backward:
		return sequence.duplicate()
	var reversed: Array[int] = sequence.duplicate()
	reversed.reverse()
	return reversed


func check(answer: Array[int]) -> bool:
	var success := answer == expected()
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
		PackedStringArray(["RESULT_DIRECTION", "DIGIT_BACKWARD" if backward else "DIGIT_FORWARD"]),
		PackedStringArray(["RESULT_ROUNDS", "%d / %d" % [tracker.correct_rounds, tracker.rounds]]),
	]
	result.details = {"span": tracker.span, "backward": backward, "rounds": tracker.rounds}
	return result
