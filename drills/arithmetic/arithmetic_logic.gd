## Mental arithmetic sprint: as many additions, subtractions and
## multiplications as possible within a time limit.
class_name ArithmeticLogic
extends RefCounted

enum Op { ADD, SUB, MUL }

var duration_s: int
var a: int = 0
var b: int = 0
var op: Op = Op.ADD
var correct_count: int = 0
var wrong_count: int = 0
var answer_times := ReactionStats.new()
var _rng: RandomNumberGenerator


func _init(p_duration_s: int, rng: RandomNumberGenerator) -> void:
	duration_s = p_duration_s
	_rng = rng


func new_problem() -> String:
	op = _rng.randi_range(0, 2) as Op
	match op:
		Op.ADD:
			a = _rng.randi_range(11, 89)
			b = _rng.randi_range(11, 89)
		Op.SUB:
			a = _rng.randi_range(30, 99)
			b = _rng.randi_range(11, a - 1)
		Op.MUL:
			a = _rng.randi_range(3, 12)
			b = _rng.randi_range(3, 12)
	return problem_text()


func problem_text() -> String:
	var symbol := "+"
	if op == Op.SUB:
		symbol = "−"
	elif op == Op.MUL:
		symbol = "×"
	return "%d %s %d" % [a, symbol, b]


func solution() -> int:
	match op:
		Op.ADD:
			return a + b
		Op.SUB:
			return a - b
	return a * b


func check(answer: int, time_ms: int) -> bool:
	var correct := answer == solution()
	if correct:
		correct_count += 1
		answer_times.add(time_ms)
	else:
		wrong_count += 1
	return correct


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = duration_s * 1000
	result.error_count = wrong_count
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["ARITH_CORRECT", str(correct_count)]),
		PackedStringArray(["RESULT_WRONG", str(wrong_count)]),
		PackedStringArray(["ARITH_PER_ANSWER", Format.seconds(roundi(answer_times.mean()))]),
	]
	result.details = {"correct": correct_count, "wrong": wrong_count, "duration_s": duration_s}
	return result
