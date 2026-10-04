## Visual search: one target letter among distractors; click it.
class_name SearchLogic
extends RefCounted

const PAIRS: Array[String] = ["OQ", "EF", "TL", "PR", "CG", "VY"]

var trials: int
var set_size: int
var current: int = 0
var target_index: Array[int] = []
var target_letter: Array[String] = []
var distractor_letter: Array[String] = []
var stats := ReactionStats.new()
var wrong_count: int = 0


func _init(p_trials: int, p_set_size: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	set_size = p_set_size
	for i in trials:
		var pair := PAIRS[rng.randi_range(0, PAIRS.size() - 1)]
		var swap := rng.randi_range(0, 1) == 1
		target_letter.append(pair[1] if swap else pair[0])
		distractor_letter.append(pair[0] if swap else pair[1])
		target_index.append(rng.randi_range(0, set_size - 1))


func letter_at(cell: int) -> String:
	return target_letter[current] if cell == target_index[current] else distractor_letter[current]


func record_click(cell: int, rt_ms: int) -> bool:
	var correct := cell == target_index[current]
	if correct:
		stats.add(rt_ms)
		current += 1
	else:
		wrong_count += 1
	return correct


func is_done() -> bool:
	return current >= trials


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
		PackedStringArray(["RESULT_WRONG", str(wrong_count)]),
		PackedStringArray(["SEARCH_SET_SIZE", str(set_size)]),
	]
	result.details = {"times_ms": stats.times_ms.duplicate(), "wrong": wrong_count}
	result.metrics = {"median_rt_ms": stats.median(), "error_rate": float(wrong_count) / maxi(1, trials + wrong_count)}
	return result
