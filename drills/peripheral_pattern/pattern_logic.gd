## Peripheral pattern search: while a centre digit must be watched, a target
## pattern appears briefly in one of eight sectors among distractor patterns.
## The sector is reported with a digit, the centre changes are counted.
class_name PatternLogic
extends RefCounted

const SECTORS := 8
const SHOW_MS := 700
const MIN_GAP_MS := 1200
const MAX_GAP_MS := 2400
const CENTRE_CHANGE_RATIO := 0.35
## Patterns: bar count and whether the bars are the target colour.
const TARGET_BARS := 3

var trials: int
var target_sector: Array[int] = []
var centre_changes: Array[bool] = []
var centre_change_count: int = 0
var current: int = 0
var correct: int = 0
var reported_changes: int = -1
var _rng: RandomNumberGenerator


func _init(p_trials: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	_rng = rng
	for i in trials:
		target_sector.append(_rng.randi_range(0, SECTORS - 1))
		var changes := _rng.randf() < CENTRE_CHANGE_RATIO
		centre_changes.append(changes)
		if changes:
			centre_change_count += 1


func next_gap_ms() -> int:
	return _rng.randi_range(MIN_GAP_MS, MAX_GAP_MS)


func next_digit(previous: int) -> int:
	var digit := _rng.randi_range(0, 9)
	if digit == previous:
		digit = (digit + 1) % 10
	return digit


## Bars shown in [param sector] for the current trial: the target has three
## target-coloured bars, distractors differ in count or colour.
func pattern_for(sector: int) -> Dictionary:
	if sector == target_sector[current]:
		return {"bars": TARGET_BARS, "target_color": true}
	var kind := _rng.randi_range(0, 2)
	if kind == 0:
		return {"bars": 2, "target_color": true}
	if kind == 1:
		return {"bars": TARGET_BARS, "target_color": false}
	return {"bars": 4, "target_color": true}


func answer(sector: int) -> bool:
	var ok := sector == target_sector[current]
	if ok:
		correct += 1
	current += 1
	return ok


func is_done() -> bool:
	return current >= trials


func report_centre_changes(count: int) -> bool:
	reported_changes = count
	return count == centre_change_count


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.error_count = trials - correct + (0 if reported_changes == centre_change_count else 1)
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["PATTERN_FOUND", "%d / %d" % [correct, trials]]),
		PackedStringArray(["PERIPHERAL_CENTRE", "%d / %d" % [reported_changes, centre_change_count]]),
	]
	result.details = {"correct": correct, "centre_changes": centre_change_count, "reported": reported_changes}
	return result
