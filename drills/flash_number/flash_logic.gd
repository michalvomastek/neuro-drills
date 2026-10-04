## Flashing number: a multi-digit number appears briefly off-centre and has to
## be typed back. Digit count adapts through SpanTracker.
class_name FlashLogic
extends RefCounted

const START_DIGITS := 4
const MAX_DIGITS := 9
const FLASH_MS := 250
## Relative offset from the centre where the number appears.
const OFFSETS: Array[Vector2] = [
	Vector2(-0.3, -0.25), Vector2(0.3, -0.25), Vector2(-0.3, 0.25), Vector2(0.3, 0.25),
	Vector2(0.0, -0.3), Vector2(0.0, 0.3), Vector2(-0.35, 0.0), Vector2(0.35, 0.0),
]

var tracker := SpanTracker.new(START_DIGITS, MAX_DIGITS)
var number: String = ""
var offset: Vector2 = Vector2.ZERO
var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


func new_round() -> String:
	number = ""
	for i in tracker.length:
		number += str(_rng.randi_range(1 if i == 0 else 0, 9))
	offset = OFFSETS[_rng.randi_range(0, OFFSETS.size() - 1)]
	return number


func check(answer: String) -> bool:
	var success := answer == number
	tracker.record(success)
	return success


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.error_count = tracker.rounds - tracker.correct_rounds
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["FLASH_DIGITS", str(tracker.span)]),
		PackedStringArray(["RESULT_ROUNDS", "%d / %d" % [tracker.correct_rounds, tracker.rounds]]),
	]
	result.details = {"span": tracker.span, "rounds": tracker.rounds}
	result.metrics = {"digits": float(tracker.span)}
	return result
