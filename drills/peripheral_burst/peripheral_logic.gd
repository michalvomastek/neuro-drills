## Peripheral burst: brief flashes around a fixation point have to be detected
## without looking away. The centre digit changes now and then; reporting how
## often confirms the gaze stayed in the middle.
class_name PeripheralLogic
extends RefCounted

const FLASH_MS := 200
const RESPONSE_WINDOW_MS := 1000
const MIN_GAP_MS := 900
const MAX_GAP_MS := 2200
const MIN_RADIUS := 0.34
const MAX_RADIUS := 0.47
const CENTRE_CHANGE_RATIO := 0.3

var trials: int
## Flash positions relative to the centre, in units of the shorter stage side.
var offsets: Array[Vector2] = []
## Whether the centre digit changes right before this flash.
var centre_changes: Array[bool] = []
var current: int = 0
var detect_stats := ReactionStats.new()
var misses: int = 0
var centre_change_count: int = 0
var reported_changes: int = -1
var _responded: bool = false
var _rng: RandomNumberGenerator


func _init(p_trials: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	_rng = rng
	for i in trials:
		var angle := _rng.randf_range(0.0, TAU)
		var radius := _rng.randf_range(MIN_RADIUS, MAX_RADIUS)
		offsets.append(Vector2(cos(angle), sin(angle)) * radius)
		var changes := _rng.randf() < CENTRE_CHANGE_RATIO
		centre_changes.append(changes)
		if changes:
			centre_change_count += 1


func next_gap_ms() -> int:
	return _rng.randi_range(MIN_GAP_MS, MAX_GAP_MS)


func next_centre_digit(previous: int) -> int:
	var digit := _rng.randi_range(0, 9)
	if digit == previous:
		digit = (digit + 1) % 10
	return digit


## A response inside the window of the current flash; returns false when it was already counted.
func respond(rt_ms: int) -> bool:
	if _responded:
		return false
	_responded = true
	detect_stats.add(rt_ms)
	return true


func close_window() -> void:
	if not _responded:
		misses += 1
	_responded = false
	current += 1


func is_done() -> bool:
	return current >= trials


func report_centre_changes(count: int) -> bool:
	reported_changes = count
	return count == centre_change_count


func detection_rate() -> float:
	return float(detect_stats.count()) / trials if trials > 0 else 0.0


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(detect_stats.mean())
	result.error_count = misses + (0 if reported_changes == centre_change_count else 1)
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["PERIPHERAL_DETECTED", "%d / %d" % [detect_stats.count(), trials]]),
		PackedStringArray(["RESULT_MEAN_RT", Format.millis(detect_stats.mean())]),
		PackedStringArray(["PERIPHERAL_CENTRE", "%d / %d" % [reported_changes, centre_change_count]]),
	]
	result.details = {"times_ms": detect_stats.times_ms.duplicate(), "misses": misses, "centre_changes": centre_change_count, "reported": reported_changes}
	return result
