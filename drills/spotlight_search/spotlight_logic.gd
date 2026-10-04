## Spotlight search: several targets hide among distractors; only a small
## circle around the pointer is visible, so the scene must be scanned.
class_name SpotlightLogic
extends RefCounted

const TARGET := "T"
const DISTRACTOR := "L"

var set_size: int
var target_count: int
var targets: Array[int] = []
var found: Array[int] = []
var wrong_count: int = 0
var found_at_ms: Array[int] = []
var _rng: RandomNumberGenerator


func _init(p_set_size: int, p_target_count: int, rng: RandomNumberGenerator) -> void:
	set_size = p_set_size
	target_count = p_target_count
	_rng = rng
	var pool: Array[int] = []
	for i in set_size:
		pool.append(i)
	for i in target_count:
		targets.append(pool.pop_at(_rng.randi_range(0, pool.size() - 1)))


func letter_at(cell: int) -> String:
	return TARGET if targets.has(cell) else DISTRACTOR


## Returns true when the cell was an unfound target.
func click(cell: int, elapsed_ms: int) -> bool:
	if targets.has(cell) and not found.has(cell):
		found.append(cell)
		found_at_ms.append(elapsed_ms)
		return true
	wrong_count += 1
	return false


func is_done() -> bool:
	return found.size() >= target_count


func total_time_ms() -> int:
	return found_at_ms[found_at_ms.size() - 1] if not found_at_ms.is_empty() else 0


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = total_time_ms()
	result.error_count = wrong_count
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["RESULT_TIME", Format.seconds(total_time_ms())]),
		PackedStringArray(["RESULT_WRONG", str(wrong_count)]),
		PackedStringArray(["SPOTLIGHT_PER_TARGET", Format.seconds(roundi(float(total_time_ms()) / maxi(1, target_count)))]),
	]
	result.details = {"found_at_ms": found_at_ms.duplicate(), "wrong": wrong_count}
	result.metrics = {"ms_per_target": float(total_time_ms()) / maxi(1, target_count)}
	return result
