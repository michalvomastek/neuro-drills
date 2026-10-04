## Go/No-Go: respond to go stimuli, withhold on no-go stimuli.
class_name GoNoGoLogic
extends RefCounted

const GO_RATIO := 0.75
const STIMULUS_MS := 900
const MIN_GAP_MS := 600
const MAX_GAP_MS := 1400

var trials: int
## True where the trial is a go trial.
var is_go: Array[bool] = []
var current: int = 0
var hit_stats := ReactionStats.new()
var misses: int = 0
var false_alarms: int = 0
var correct_rejections: int = 0
var _rng: RandomNumberGenerator


func _init(p_trials: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	_rng = rng
	var go_count := maxi(1, roundi(trials * GO_RATIO))
	for i in trials:
		is_go.append(i < go_count)
	# Shuffle so no-go trials land anywhere.
	for i in range(is_go.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := is_go[i]
		is_go[i] = is_go[j]
		is_go[j] = swap


func next_gap_ms() -> int:
	return _rng.randi_range(MIN_GAP_MS, MAX_GAP_MS)


func current_is_go() -> bool:
	return is_go[current]


## A response during the current stimulus. Returns true when it was correct (a hit).
func record_response(rt_ms: int) -> bool:
	var correct := is_go[current]
	if correct:
		hit_stats.add(rt_ms)
	else:
		false_alarms += 1
	current += 1
	return correct


## No response during the current stimulus. Returns true when that was correct.
func record_no_response() -> bool:
	var correct := not is_go[current]
	if correct:
		correct_rejections += 1
	else:
		misses += 1
	current += 1
	return correct


func is_done() -> bool:
	return current >= trials


func accuracy() -> float:
	return float(trials - misses - false_alarms) / trials if trials > 0 else 0.0


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(hit_stats.median())
	result.error_count = misses + false_alarms
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["RESULT_HITS_RT", Format.millis(hit_stats.mean())]),
		PackedStringArray(["RESULT_ACCURACY", Format.percent(accuracy())]),
		PackedStringArray(["RESULT_FALSE_ALARMS", str(false_alarms)]),
		PackedStringArray(["RESULT_MISSES", str(misses)]),
	]
	result.details = {
		"hit_times_ms": hit_stats.times_ms.duplicate(),
		"misses": misses,
		"false_alarms": false_alarms,
		"correct_rejections": correct_rejections,
	}
	return result
