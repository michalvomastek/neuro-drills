## Pure game logic of the Schulte table: number layout, click evaluation and
## timing bookkeeping. No scene access, so it runs in headless tests.
class_name SchulteLogic
extends RefCounted

enum ClickOutcome { CORRECT, WRONG, COMPLETED, IGNORED }

var grid_size: int
## Number shown in each cell, row by row.
var cells: Array[int] = []
var next_target: int = 1
var finished: bool = false
var error_count: int = 0
## Elapsed time (ms since the grid appeared) at which each target was found.
var found_at_ms: Array[int] = []
## Wrong clicks per target number that was being searched for at the time.
var errors_by_target: Dictionary = {}


func _init(p_grid_size: int, rng: RandomNumberGenerator) -> void:
	grid_size = p_grid_size
	for number in range(1, total_count() + 1):
		cells.append(number)
	# Fisher-Yates with the injected generator keeps layouts reproducible.
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := cells[i]
		cells[i] = cells[j]
		cells[j] = swap


func total_count() -> int:
	return grid_size * grid_size


func register_click(cell_index: int, elapsed_ms: int) -> ClickOutcome:
	if finished or cell_index < 0 or cell_index >= cells.size():
		return ClickOutcome.IGNORED
	if cells[cell_index] != next_target:
		error_count += 1
		var previous_errors: int = errors_by_target.get(next_target, 0)
		errors_by_target[next_target] = previous_errors + 1
		return ClickOutcome.WRONG
	found_at_ms.append(elapsed_ms)
	next_target += 1
	if next_target > total_count():
		finished = true
		return ClickOutcome.COMPLETED
	return ClickOutcome.CORRECT


func total_time_ms() -> int:
	return found_at_ms[found_at_ms.size() - 1] if not found_at_ms.is_empty() else 0


## Time spent searching for each found target, in order.
func search_times_ms() -> Array[int]:
	var times: Array[int] = []
	var previous := 0
	for stamp in found_at_ms:
		times.append(stamp - previous)
		previous = stamp
	return times


## The found number that took longest to locate, or 0 when nothing was found yet.
func slowest_target() -> int:
	var slowest := 0
	var slowest_ms := -1
	var times := search_times_ms()
	for i in times.size():
		if times[i] > slowest_ms:
			slowest_ms = times[i]
			slowest = i + 1
	return slowest


func average_ms_per_target() -> float:
	if found_at_ms.is_empty():
		return 0.0
	return float(total_time_ms()) / found_at_ms.size()


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = total_time_ms()
	result.error_count = error_count
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	var slowest := slowest_target()
	var times := search_times_ms()
	result.summary_rows = [
		PackedStringArray(["RESULT_AVERAGE_PER_NUMBER", Format.seconds(int(average_ms_per_target()))]),
		PackedStringArray(["RESULT_SLOWEST_NUMBER", "%d (%s)" % [slowest, Format.seconds(times[slowest - 1])]]),
		PackedStringArray(["RESULT_FIRST_CLICK", Format.seconds(found_at_ms[0])]),
	]
	result.details = {
		"grid_size": grid_size,
		"found_at_ms": found_at_ms.duplicate(),
		"errors_by_target": errors_by_target.duplicate(),
	}
	return result
