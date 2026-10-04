## Memory matrix: a set of cells lights up briefly, then has to be tapped back.
## The number of cells adapts: up after a correct round, down after a wrong one.
class_name MatrixLogic
extends RefCounted

const START_LEVEL := 3
const MIN_LEVEL := 2

var size: int
var rounds: int
var level: int = START_LEVEL
var max_level: int = 0
var rounds_done: int = 0
var rounds_correct: int = 0
var pattern: Array[int] = []
var selected: Array[int] = []
var _rng: RandomNumberGenerator


func _init(p_size: int, p_rounds: int, rng: RandomNumberGenerator) -> void:
	size = p_size
	rounds = p_rounds
	_rng = rng


func cell_count() -> int:
	return size * size


func max_possible_level() -> int:
	return cell_count() / 2


## Draws a new pattern of [member level] distinct cells.
func new_round() -> Array[int]:
	var pool: Array[int] = []
	for i in cell_count():
		pool.append(i)
	pattern.clear()
	selected.clear()
	for i in level:
		var pick := _rng.randi_range(0, pool.size() - 1)
		pattern.append(pool[pick])
		pool.remove_at(pick)
	return pattern


## Marks a cell; returns false when it was already selected or the round is full.
func select(index: int) -> bool:
	if selected.has(index) or is_round_complete():
		return false
	selected.append(index)
	return true


func is_round_complete() -> bool:
	return selected.size() >= pattern.size()


func round_correct() -> bool:
	for cell in selected:
		if not pattern.has(cell):
			return false
	return selected.size() == pattern.size()


## Scores the finished round and adapts the level; returns whether it was correct.
func finish_round() -> bool:
	var correct := round_correct()
	rounds_done += 1
	if correct:
		rounds_correct += 1
		max_level = maxi(max_level, level)
		level = mini(level + 1, max_possible_level())
	else:
		level = maxi(MIN_LEVEL, level - 1)
	return correct


func is_done() -> bool:
	return rounds_done >= rounds


func accuracy() -> float:
	return float(rounds_correct) / rounds if rounds > 0 else 0.0


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.error_count = rounds_done - rounds_correct
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["RESULT_MAX_LEVEL", str(max_level)]),
		PackedStringArray(["RESULT_ROUNDS", "%d / %d" % [rounds_correct, rounds_done]]),
		PackedStringArray(["RESULT_ACCURACY", Format.percent(accuracy())]),
	]
	result.details = {"max_level": max_level, "rounds_correct": rounds_correct}
	result.metrics = {"max_level": float(max_level)}
	return result
