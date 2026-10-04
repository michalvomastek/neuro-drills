## Visual N-back: a square lights up in a 3x3 grid; respond when the position
## matches the one N steps earlier.
class_name NBackLogic
extends RefCounted

const POSITIONS := 9
const TARGET_RATIO := 0.3
const STIMULUS_MS := 500
const INTERVAL_MS := 2500

var n: int
var trials: int
var positions: Array[int] = []
var responded: Array[bool] = []
var evaluated: int = 0
var hits: int = 0
var misses: int = 0
var false_alarms: int = 0
var correct_rejections: int = 0


func _init(p_n: int, p_trials: int, rng: RandomNumberGenerator) -> void:
	n = p_n
	trials = p_trials
	for i in trials:
		var position: int
		if i >= n and rng.randf() < TARGET_RATIO:
			position = positions[i - n]
		else:
			position = rng.randi_range(0, POSITIONS - 1)
			if i >= n and position == positions[i - n]:
				position = (position + 1) % POSITIONS
		positions.append(position)
		responded.append(false)


func is_target(index: int) -> bool:
	return index >= n and positions[index] == positions[index - n]


func target_count() -> int:
	var count := 0
	for i in trials:
		if is_target(i):
			count += 1
	return count


## A response inside the window of stimulus [param index]; returns whether it was a hit.
func respond(index: int) -> bool:
	if responded[index]:
		return is_target(index)
	responded[index] = true
	return is_target(index)


## Closes the window of stimulus [param index] and scores it.
func evaluate(index: int) -> void:
	evaluated = index + 1
	if is_target(index):
		if responded[index]:
			hits += 1
		else:
			misses += 1
	elif responded[index]:
		false_alarms += 1
	else:
		correct_rejections += 1


func is_done() -> bool:
	return evaluated >= trials


func accuracy() -> float:
	return float(hits + correct_rejections) / trials if trials > 0 else 0.0


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = 0
	result.error_count = misses + false_alarms
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["RESULT_NBACK_LEVEL", str(n)]),
		PackedStringArray(["RESULT_ACCURACY", Format.percent(accuracy())]),
		PackedStringArray(["RESULT_HITS", "%d / %d" % [hits, target_count()]]),
		PackedStringArray(["RESULT_FALSE_ALARMS", str(false_alarms)]),
	]
	result.details = {"n": n, "hits": hits, "misses": misses, "false_alarms": false_alarms}
	return result
