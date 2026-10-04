## Simon effect: an arrow appears on the left or right; respond to where it
## points, not where it is. Congruent when side and direction agree.
class_name SimonEffectLogic
extends RefCounted

const CONGRUENT_RATIO := 0.5
const MIN_DELAY_MS := 700
const MAX_DELAY_MS := 1500

var trials: int
var sides: Array[int] = []
var directions: Array[int] = []
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
		var direction := _rng.randi_range(0, 1)
		directions.append(direction)
		sides.append(direction if i < congruent_count else 1 - direction)
	for i in range(trials - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var side_swap := sides[i]
		sides[i] = sides[j]
		sides[j] = side_swap
		var dir_swap := directions[i]
		directions[i] = directions[j]
		directions[j] = dir_swap


func next_delay_ms() -> int:
	return _rng.randi_range(MIN_DELAY_MS, MAX_DELAY_MS)


func current_is_congruent() -> bool:
	return sides[current] == directions[current]


func record_response(direction: int, rt_ms: int) -> bool:
	var correct := direction == directions[current]
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


func simon_effect_ms() -> float:
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
		PackedStringArray(["SIMON_EFFECT", Format.millis(simon_effect_ms())]),
	]
	result.details = {"congruent_ms": congruent_stats.times_ms.duplicate(), "incongruent_ms": incongruent_stats.times_ms.duplicate(), "wrong": wrong_count}
	result.metrics = {"interference_ms": simon_effect_ms(), "error_rate": 1.0 - accuracy()}
	return result
