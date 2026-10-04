## Pure game logic of the Schulte table and its variants: symbol layout, click
## evaluation and timing bookkeeping. No scene access, so it runs in headless
## tests. A cell is a value plus a colour (0 = primary, 1 = red); the targets
## are the cells in the order they have to be found.
class_name SchulteLogic
extends RefCounted

enum ClickOutcome { CORRECT, WRONG, COMPLETED, IGNORED }

const COLOR_PRIMARY := 0
const COLOR_RED := 1

var config: SchulteConfig
var grid_size: int
## Value and colour of the symbol shown in each cell, row by row.
var cell_values: Array[int] = []
var cell_colors: Array[int] = []
## The required order: value and colour of each target.
var target_values: Array[int] = []
var target_colors: Array[int] = []
## Index into the target arrays of the symbol being searched for.
var next_index: int = 0
var finished: bool = false
var error_count: int = 0
## Elapsed time (ms since the grid appeared) at which each target was found.
var found_at_ms: Array[int] = []
## Wrong clicks per target position that was being searched for at the time.
var errors_by_target: Dictionary = {}
var _rng: RandomNumberGenerator


func _init(p_config: SchulteConfig, rng: RandomNumberGenerator) -> void:
	config = p_config
	config.normalize()
	grid_size = config.grid_size
	_rng = rng
	_build_targets()
	cell_values = target_values.duplicate()
	cell_colors = target_colors.duplicate()
	_shuffle_cells()


func _build_targets() -> void:
	if config.red_black:
		# 1 black, 24 red, 2 black, 23 red, ... 24 black, 1 red, 25 black.
		for i in range(1, 26):
			target_values.append(i)
			target_colors.append(COLOR_PRIMARY)
			if i <= 24:
				target_values.append(25 - i)
				target_colors.append(COLOR_RED)
	else:
		for number in range(1, total_count() + 1):
			target_values.append(number)
			target_colors.append(COLOR_PRIMARY)
	if config.reverse:
		target_values.reverse()
		target_colors.reverse()


func _shuffle_cells() -> void:
	# Fisher-Yates with the injected generator keeps layouts reproducible.
	for i in range(cell_values.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var value_swap := cell_values[i]
		cell_values[i] = cell_values[j]
		cell_values[j] = value_swap
		var color_swap := cell_colors[i]
		cell_colors[i] = cell_colors[j]
		cell_colors[j] = color_swap


func total_count() -> int:
	return grid_size * grid_size


## Number of targets still to find in total (49 for red-black, N*N otherwise).
func target_count() -> int:
	return target_values.size()


## Text shown in a cell: a number, or a letter for letter tables.
func label_for(cell_index: int) -> String:
	return symbol_text(cell_values[cell_index])


func symbol_text(value: int) -> String:
	if config.symbols == SchulteConfig.SYMBOLS_LETTERS:
		return char(64 + value)
	return str(value)


func is_red(cell_index: int) -> bool:
	return cell_colors[cell_index] == COLOR_RED


## Whether the symbol in [param cell_index] has already been found.
func is_found(cell_index: int) -> bool:
	for i in next_index:
		if target_values[i] == cell_values[cell_index] and target_colors[i] == cell_colors[cell_index]:
			return true
	return false


func next_target_value() -> int:
	return target_values[mini(next_index, target_count() - 1)]


func next_target_is_red() -> bool:
	return target_colors[mini(next_index, target_count() - 1)] == COLOR_RED


func next_target_text() -> String:
	return symbol_text(next_target_value())


func register_click(cell_index: int, elapsed_ms: int) -> ClickOutcome:
	if finished or cell_index < 0 or cell_index >= cell_values.size():
		return ClickOutcome.IGNORED
	if cell_values[cell_index] != target_values[next_index] or cell_colors[cell_index] != target_colors[next_index]:
		error_count += 1
		var previous_errors: int = errors_by_target.get(next_index, 0)
		errors_by_target[next_index] = previous_errors + 1
		return ClickOutcome.WRONG
	found_at_ms.append(elapsed_ms)
	next_index += 1
	if next_index >= target_count():
		finished = true
		return ClickOutcome.COMPLETED
	if config.shuffle_after_click:
		_shuffle_cells()
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


## Text of the found target that took longest to locate, or "" when nothing was found yet.
func slowest_target_text() -> String:
	var slowest := -1
	var slowest_ms := -1
	var times := search_times_ms()
	for i in times.size():
		if times[i] > slowest_ms:
			slowest_ms = times[i]
			slowest = i
	if slowest < 0:
		return ""
	var text := symbol_text(target_values[slowest])
	if config.red_black and target_colors[slowest] == COLOR_RED:
		text += " (R)"
	return text


func average_ms_per_target() -> float:
	if found_at_ms.is_empty():
		return 0.0
	return float(total_time_ms()) / found_at_ms.size()


func variant_key() -> String:
	if config.red_black:
		return "SCHULTE_VARIANT_RED_BLACK"
	if config.symbols == SchulteConfig.SYMBOLS_LETTERS:
		return "SCHULTE_VARIANT_LETTERS"
	return "SCHULTE_VARIANT_NUMBERS"


func build_result(drill_id: StringName, config_dict: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config_dict
	result.total_ms = total_time_ms()
	result.error_count = error_count
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	var times := search_times_ms()
	var slowest_ms: int = times.max() if not times.is_empty() else 0
	result.summary_rows = [
		PackedStringArray(["RESULT_TIME", Format.seconds(result.total_ms)]),
		PackedStringArray(["RESULT_ERRORS", str(error_count)]),
		PackedStringArray(["RESULT_AVERAGE_PER_NUMBER", Format.seconds(int(average_ms_per_target()))]),
		PackedStringArray(["RESULT_SLOWEST_NUMBER", "%s (%s)" % [slowest_target_text(), Format.seconds(slowest_ms)]]),
		PackedStringArray(["RESULT_FIRST_CLICK", Format.seconds(found_at_ms[0] if not found_at_ms.is_empty() else 0)]),
	]
	result.details = {
		"grid_size": grid_size,
		"variant": variant_key(),
		"found_at_ms": found_at_ms.duplicate(),
		"errors_by_target": errors_by_target.duplicate(),
	}
	result.metrics = {"total_ms": float(result.total_ms), "errors": float(error_count)}
	return result


## Schulte test indices from the times of five tables: work efficiency
## ER = mean time, warm-up WU = T1 / ER, psychic stability PS = T4 / ER.
static func test_indices(table_times_ms: Array[int]) -> Dictionary:
	if table_times_ms.is_empty():
		return {"er_ms": 0.0, "wu": 0.0, "ps": 0.0}
	var sum := 0
	for t in table_times_ms:
		sum += t
	var er := float(sum) / table_times_ms.size()
	var fourth := table_times_ms[mini(3, table_times_ms.size() - 1)]
	return {
		"er_ms": er,
		"wu": table_times_ms[0] / er if er > 0.0 else 0.0,
		"ps": fourth / er if er > 0.0 else 0.0,
	}


## Result of a whole Schulte test (several tables in a row).
static func build_test_result(drill_id: StringName, config_dict: Dictionary, table_times_ms: Array[int], errors: int) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config_dict
	var indices := test_indices(table_times_ms)
	var er: float = indices["er_ms"]
	var wu: float = indices["wu"]
	var ps: float = indices["ps"]
	result.total_ms = roundi(er)
	result.error_count = errors
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	var rows: Array[PackedStringArray] = []
	for i in table_times_ms.size():
		rows.append(PackedStringArray(["SCHULTE_TEST_T%d" % (i + 1), Format.seconds(table_times_ms[i])]))
	rows.append(PackedStringArray(["SCHULTE_TEST_ER", Format.seconds(roundi(er))]))
	rows.append(PackedStringArray(["SCHULTE_TEST_WU", Format.ratio(wu)]))
	rows.append(PackedStringArray(["SCHULTE_TEST_PS", Format.ratio(ps)]))
	rows.append(PackedStringArray(["RESULT_ERRORS", str(errors)]))
	result.summary_rows = rows
	result.details = {"table_times_ms": table_times_ms.duplicate(), "er_ms": er, "wu": wu, "ps": ps}
	result.metrics = {"total_ms": er, "errors": float(errors)}
	return result

