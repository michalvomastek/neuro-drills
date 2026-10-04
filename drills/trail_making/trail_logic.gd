## Trail Making: connect scattered nodes in order. Part A: 1, 2, 3...
## Part B: 1, A, 2, B, ... alternating numbers and letters.
class_name TrailLogic
extends RefCounted

const LETTERS := "ABCDEFGHIJKLM"
const MIN_DISTANCE := 0.17
const PLACEMENT_ATTEMPTS := 400
const MARGIN := 0.06

var count: int
var part_b: bool
var labels: Array[String] = []
## Node centres in board-relative coordinates.
var positions: Array[Vector2] = []
var next_index: int = 0
var error_count: int = 0
var found_at_ms: Array[int] = []
var finished: bool = false


func _init(p_count: int, p_part_b: bool, rng: RandomNumberGenerator) -> void:
	count = p_count
	part_b = p_part_b
	for i in count:
		if part_b and i % 2 == 1:
			labels.append(LETTERS[i / 2])
		else:
			labels.append(str(i / 2 + 1 if part_b else i + 1))
	positions = _scatter(count, rng)


## Rejection sampling with a shrinking distance so placement always terminates.
func _scatter(n: int, rng: RandomNumberGenerator) -> Array[Vector2]:
	var placed: Array[Vector2] = []
	var min_distance := MIN_DISTANCE
	while placed.size() < n:
		var ok := false
		for attempt in PLACEMENT_ATTEMPTS:
			var candidate := Vector2(rng.randf_range(MARGIN, 1.0 - MARGIN), rng.randf_range(MARGIN, 1.0 - MARGIN))
			var clear := true
			for other in placed:
				if other.distance_to(candidate) < min_distance:
					clear = false
					break
			if clear:
				placed.append(candidate)
				ok = true
				break
		if not ok:
			min_distance *= 0.85
	return placed


## Returns true when [param index] was the next node in order.
func register_click(index: int, elapsed_ms: int) -> bool:
	if finished:
		return false
	if index != next_index:
		error_count += 1
		return false
	found_at_ms.append(elapsed_ms)
	next_index += 1
	if next_index >= count:
		finished = true
	return true


func total_time_ms() -> int:
	return found_at_ms[found_at_ms.size() - 1] if not found_at_ms.is_empty() else 0


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = total_time_ms()
	result.error_count = error_count
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["RESULT_PART", "TRAIL_PART_B" if part_b else "TRAIL_PART_A"]),
		PackedStringArray(["RESULT_TIME", Format.seconds(total_time_ms())]),
		PackedStringArray(["RESULT_ERRORS", str(error_count)]),
		PackedStringArray(["RESULT_AVERAGE_PER_NUMBER", Format.seconds(roundi(float(total_time_ms()) / count))]),
	]
	result.details = {"found_at_ms": found_at_ms.duplicate(), "part_b": part_b}
	return result
