## Flanker: respond to the middle arrow of five; the flankers agree or disagree.
class_name FlankerLogic
extends RefCounted

const CONGRUENT_RATIO := 0.5
const MIN_DELAY_MS := 600
const MAX_DELAY_MS := 1400

var trials: int
## Target direction per trial: 0 = left, 1 = right.
var target: Array[int] = []
var congruent: Array[bool] = []
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
		target.append(_rng.randi_range(0, 1))
		congruent.append(i < congruent_count)
	for i in range(trials - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := congruent[i]
		congruent[i] = congruent[j]
		congruent[j] = swap


func next_delay_ms() -> int:
	return _rng.randi_range(MIN_DELAY_MS, MAX_DELAY_MS)


## The five-arrow stimulus for the current trial, e.g. "<<><<".
func current_stimulus() -> String:
	var middle := "<" if target[current] == 0 else ">"
	var flank := middle if congruent[current] else (">" if middle == "<" else "<")
	return flank + flank + middle + flank + flank


func record_response(side: int, rt_ms: int) -> bool:
	var correct := side == target[current]
	if correct:
		if congruent[current]:
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


func flanker_effect_ms() -> float:
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
		PackedStringArray(["RESULT_INTERFERENCE", Format.millis(flanker_effect_ms())]),
	]
	result.details = {
		"congruent_ms": congruent_stats.times_ms.duplicate(),
		"incongruent_ms": incongruent_stats.times_ms.duplicate(),
		"wrong": wrong_count,
	}
	result.metrics = {"interference_ms": flanker_effect_ms(), "error_rate": 1.0 - accuracy()}
	return result
