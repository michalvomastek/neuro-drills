## Stroop: a colour word printed in an ink colour; answer the ink colour.
class_name StroopLogic
extends RefCounted

const COLOR_COUNT := 4
const CONGRUENT_RATIO := 0.5

var trials: int
var word_index: Array[int] = []
var ink_index: Array[int] = []
var current: int = 0
var congruent_stats := ReactionStats.new()
var incongruent_stats := ReactionStats.new()
var wrong_count: int = 0
var _rng: RandomNumberGenerator


func _init(p_trials: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	_rng = rng
	var congruent_count := roundi(trials * CONGRUENT_RATIO)
	for i in trials:
		var ink := _rng.randi_range(0, COLOR_COUNT - 1)
		ink_index.append(ink)
		if i < congruent_count:
			word_index.append(ink)
		else:
			word_index.append((ink + _rng.randi_range(1, COLOR_COUNT - 1)) % COLOR_COUNT)
	for i in range(trials - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var word_swap := word_index[i]
		word_index[i] = word_index[j]
		word_index[j] = word_swap
		var ink_swap := ink_index[i]
		ink_index[i] = ink_index[j]
		ink_index[j] = ink_swap


func current_is_congruent() -> bool:
	return word_index[current] == ink_index[current]


func record_response(color: int, rt_ms: int) -> bool:
	var correct := color == ink_index[current]
	if correct:
		if current_is_congruent():
			congruent_stats.add(rt_ms)
		else:
			incongruent_stats.add(rt_ms)
	else:
		wrong_count += 1
	current += 1
	return correct


func is_done() -> bool:
	return current >= trials


func accuracy() -> float:
	return float(trials - wrong_count) / trials if trials > 0 else 0.0


func interference_ms() -> float:
	return incongruent_stats.mean() - congruent_stats.mean()


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(incongruent_stats.mean())
	result.error_count = wrong_count
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["RESULT_ACCURACY", Format.percent(accuracy())]),
		PackedStringArray(["RESULT_RT_CONGRUENT", Format.millis(congruent_stats.mean())]),
		PackedStringArray(["RESULT_RT_INCONGRUENT", Format.millis(incongruent_stats.mean())]),
		PackedStringArray(["RESULT_INTERFERENCE", Format.millis(interference_ms())]),
	]
	result.details = {
		"congruent_ms": congruent_stats.times_ms.duplicate(),
		"incongruent_ms": incongruent_stats.times_ms.duplicate(),
		"wrong": wrong_count,
	}
	result.metrics = {"interference_ms": interference_ms(), "error_rate": 1.0 - accuracy()}
	return result
