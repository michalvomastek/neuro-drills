## Posner cueing: a central arrow cue precedes a side target; the cue is valid
## most of the time. Compares reaction times after valid and invalid cues.
class_name PosnerLogic
extends RefCounted

const VALID_RATIO := 0.8
const CUE_MS := 200
const MIN_SOA_MS := 100
const MAX_SOA_MS := 300
const MIN_DELAY_MS := 600
const MAX_DELAY_MS := 1200

var trials: int
var cue_side: Array[int] = []
var target_side: Array[int] = []
var current: int = 0
var valid_stats := ReactionStats.new()
var invalid_stats := ReactionStats.new()
var wrong_count: int = 0
var _rng: RandomNumberGenerator


func _init(p_trials: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	_rng = rng
	var valid_count := roundi(trials * VALID_RATIO)
	for i in trials:
		var cue := _rng.randi_range(0, 1)
		cue_side.append(cue)
		target_side.append(cue if i < valid_count else 1 - cue)
	for i in range(trials - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var cue_swap := cue_side[i]
		cue_side[i] = cue_side[j]
		cue_side[j] = cue_swap
		var target_swap := target_side[i]
		target_side[i] = target_side[j]
		target_side[j] = target_swap


func next_delay_ms() -> int:
	return _rng.randi_range(MIN_DELAY_MS, MAX_DELAY_MS)


func next_soa_ms() -> int:
	return _rng.randi_range(MIN_SOA_MS, MAX_SOA_MS)


func current_is_valid() -> bool:
	return cue_side[current] == target_side[current]


func record_response(side: int, rt_ms: int) -> bool:
	var correct := side == target_side[current]
	if correct:
		if current_is_valid():
			valid_stats.add(rt_ms)
		else:
			invalid_stats.add(rt_ms)
	else:
		wrong_count += 1
	current += 1
	return correct


func is_done() -> bool:
	return current >= trials


func accuracy() -> float:
	return float(trials - wrong_count) / trials if trials > 0 else 0.0


func validity_effect_ms() -> float:
	return invalid_stats.mean() - valid_stats.mean()


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(valid_stats.mean())
	result.error_count = wrong_count
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["RESULT_ACCURACY", Format.percent(accuracy())]),
		PackedStringArray(["POSNER_RT_VALID", Format.millis(valid_stats.mean())]),
		PackedStringArray(["POSNER_RT_INVALID", Format.millis(invalid_stats.mean())]),
		PackedStringArray(["POSNER_EFFECT", Format.millis(validity_effect_ms())]),
	]
	result.details = {"valid_ms": valid_stats.times_ms.duplicate(), "invalid_ms": invalid_stats.times_ms.duplicate(), "wrong": wrong_count}
	result.metrics = {"validity_effect_ms": validity_effect_ms(), "error_rate": 1.0 - accuracy()}
	return result
