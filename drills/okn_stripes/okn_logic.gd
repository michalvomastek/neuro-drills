## Optokinetic stripes: the background scrolls while a centre digit changes at
## random moments; react to each change without following the stripes.
class_name OknLogic
extends RefCounted

const MIN_GAP_MS := 1200
const MAX_GAP_MS := 3000
const RESPONSE_WINDOW_MS := 1200

var changes: int
var current: int = 0
var detect_stats := ReactionStats.new()
var misses: int = 0
var false_alarms: int = 0
var _responded: bool = false
var _rng: RandomNumberGenerator


func _init(p_changes: int, rng: RandomNumberGenerator) -> void:
	changes = p_changes
	_rng = rng


func next_gap_ms() -> int:
	return _rng.randi_range(MIN_GAP_MS, MAX_GAP_MS)


func next_digit(previous: int) -> int:
	var digit := _rng.randi_range(0, 9)
	if digit == previous:
		digit = (digit + 1) % 10
	return digit


## A response inside the window of the current change; returns true on first detection.
func respond(rt_ms: int) -> bool:
	if _responded:
		return false
	_responded = true
	detect_stats.add(rt_ms)
	return true


func respond_outside_window() -> void:
	false_alarms += 1


func close_window() -> void:
	if not _responded:
		misses += 1
	_responded = false
	current += 1


func is_done() -> bool:
	return current >= changes


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(detect_stats.mean())
	result.error_count = misses + false_alarms
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["OKN_DETECTED", "%d / %d" % [detect_stats.count(), changes]]),
		PackedStringArray(["RESULT_MEAN_RT", Format.millis(detect_stats.mean())]),
		PackedStringArray(["OKN_FALSE_ALARMS", str(false_alarms)]),
	]
	result.details = {"times_ms": detect_stats.times_ms.duplicate(), "misses": misses, "false_alarms": false_alarms}
	return result
