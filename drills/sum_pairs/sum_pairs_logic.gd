## Sum pairs: numbers 1-9 sit on a partly filled grid; two (or, with chains,
## more) numbers whose sum is the target are removed when they are joined by
## clear straight lines (row, column or 45-degree diagonal with no other
## number in between). Removed numbers are replaced elsewhere, so the board
## keeps its density and the run is timed. Pure logic: the scene only taps.
class_name SumPairsLogic
extends RefCounted

enum Outcome { IGNORED, SELECTED, DESELECTED, COMPLETED, BLOCKED, WRONG_SUM }

const MIN_VALUE := 1
const MAX_VALUE := 9
## Share of the cells that hold a number; the empty cells are what makes a
## line of sight matter.
const DENSITY := 0.6
const DYNAMIC_MIN := 6
const DYNAMIC_MAX := 14
const ENSURE_ATTEMPTS := 40

var size: int
var target: int
var dynamic: bool
var chains: bool
var grid: Array[int] = []
var selection: Array[int] = []
var completed: int = 0
var invalid_count: int = 0
var cleared_count: int = 0
var chain_count: int = 0
## Time between consecutive completions (or from the start to the first).
var times_ms: Array[int] = []
var distances: Array[int] = []
var _last_success_ms: int = 0
var _rng: RandomNumberGenerator


func _init(p_size: int, p_target: int, p_dynamic: bool, p_chains: bool, rng: RandomNumberGenerator) -> void:
	size = p_size
	target = p_target
	dynamic = p_dynamic
	chains = p_chains
	_rng = rng
	grid.resize(size * size)
	grid.fill(0)
	_refill(number_count())
	if dynamic:
		_pick_dynamic_target()
	_ensure_move()


func number_count() -> int:
	return ceili(size * size * DENSITY)


func value_at(cell: int) -> int:
	return grid[cell]


func is_selected(cell: int) -> bool:
	return selection.has(cell)


func selection_sum() -> int:
	var total := 0
	for cell in selection:
		total += grid[cell]
	return total


## A tap on [param cell] at [param elapsed_ms] since the start of the run.
func tap(cell: int, elapsed_ms: int) -> Outcome:
	if cell < 0 or cell >= grid.size() or grid[cell] == 0:
		return Outcome.IGNORED
	if selection.is_empty():
		selection.append(cell)
		return Outcome.SELECTED
	var last: int = selection[selection.size() - 1]
	if cell == last:
		selection.pop_back()
		return Outcome.DESELECTED
	if selection.has(cell):
		return Outcome.IGNORED
	if not line_clear(last, cell):
		invalid_count += 1
		selection.clear()
		return Outcome.BLOCKED
	var total := selection_sum() + grid[cell]
	if total == target:
		selection.append(cell)
		_complete(elapsed_ms)
		return Outcome.COMPLETED
	if chains and total < target:
		selection.append(cell)
		return Outcome.SELECTED
	invalid_count += 1
	selection.clear()
	return Outcome.WRONG_SUM


## True when the two cells share a row, column or diagonal and no number
## lies strictly between them.
func line_clear(a: int, b: int) -> bool:
	var ax := a % size
	var ay := a / size
	var bx := b % size
	var by := b / size
	var dx := bx - ax
	var dy := by - ay
	if dx == 0 and dy == 0:
		return false
	if dx != 0 and dy != 0 and absi(dx) != absi(dy):
		return false
	var steps := maxi(absi(dx), absi(dy))
	var sx := signi(dx)
	var sy := signi(dy)
	for i in range(1, steps):
		if grid[(ay + sy * i) * size + ax + sx * i] != 0:
			return false
	return true


func distance(a: int, b: int) -> int:
	return maxi(absi(a % size - b % size), absi(a / size - b / size))


## Pairs of numbers that see each other and add up to the target.
func valid_pairs() -> Array[Vector2i]:
	var pairs: Array[Vector2i] = []
	for pair in _visible_pairs():
		if grid[pair.x] + grid[pair.y] == target:
			pairs.append(pair)
	return pairs


func has_move() -> bool:
	return not valid_pairs().is_empty()


func build_result(drill_id: StringName, config: Dictionary, duration_ms: int) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = duration_ms
	result.error_count = invalid_count
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	var ms_per_pair := float(duration_ms) / completed if completed > 0 else float(duration_ms)
	var attempts := completed + invalid_count
	var invalid_rate := float(invalid_count) / attempts if attempts > 0 else 0.0
	var mean_distance := 0.0
	for d in distances:
		mean_distance += d
	mean_distance = mean_distance / distances.size() if not distances.is_empty() else 0.0
	result.summary_rows = [
		PackedStringArray(["SUMPAIRS_PAIRS", str(completed)]),
		PackedStringArray(["SUMPAIRS_PER_PAIR", Format.seconds(roundi(ms_per_pair))]),
		PackedStringArray(["SUMPAIRS_INVALID", "%d (%s)" % [invalid_count, Format.percent(invalid_rate)]]),
		PackedStringArray(["SUMPAIRS_DISTANCE", Format.ratio(mean_distance)]),
	]
	if chains:
		result.summary_rows.append(PackedStringArray(["SUMPAIRS_CHAINS", str(chain_count)]))
	result.details = {"times_ms": times_ms.duplicate(), "distances": distances.duplicate(), "cleared": cleared_count}
	result.metrics = {
		"ms_per_pair": ms_per_pair,
		"invalid_rate": invalid_rate,
		"mean_distance": mean_distance,
		"pairs": float(completed),
	}
	return result


func _complete(elapsed_ms: int) -> void:
	completed += 1
	if selection.size() > 2:
		chain_count += 1
	times_ms.append(elapsed_ms - _last_success_ms)
	_last_success_ms = elapsed_ms
	for i in range(1, selection.size()):
		distances.append(distance(selection[i - 1], selection[i]))
	var removed := selection.size()
	for cell in selection:
		grid[cell] = 0
	cleared_count += removed
	selection.clear()
	_refill(removed)
	if dynamic:
		_pick_dynamic_target()
	_ensure_move()


func _empty_cells() -> Array[int]:
	var cells: Array[int] = []
	for i in grid.size():
		if grid[i] == 0:
			cells.append(i)
	return cells


func _filled_cells() -> Array[int]:
	var cells: Array[int] = []
	for i in grid.size():
		if grid[i] != 0:
			cells.append(i)
	return cells


## Values that can take part in a pair for a fixed target; any value with a
## dynamic target.
func _random_value() -> int:
	if dynamic:
		return _rng.randi_range(MIN_VALUE, MAX_VALUE)
	return _rng.randi_range(maxi(MIN_VALUE, target - MAX_VALUE), mini(MAX_VALUE, target - MIN_VALUE))


func _refill(count: int) -> void:
	var empty := _empty_cells()
	for i in mini(count, empty.size()):
		var cell: int = empty.pop_at(_rng.randi_range(0, empty.size() - 1))
		grid[cell] = _random_value()


## Every pair of numbers that see each other, each pair once.
func _visible_pairs() -> Array[Vector2i]:
	var pairs: Array[Vector2i] = []
	var filled := _filled_cells()
	for i in filled.size():
		for j in range(i + 1, filled.size()):
			if line_clear(filled[i], filled[j]):
				pairs.append(Vector2i(filled[i], filled[j]))
	return pairs


## Makes sure at least one valid pair exists: re-rolls values, then as a last
## resort rewrites one visible pair to add up to the target.
func _ensure_move() -> void:
	for _attempt in ENSURE_ATTEMPTS:
		if has_move():
			return
		var filled := _filled_cells()
		var cell: int = filled[_rng.randi_range(0, filled.size() - 1)]
		grid[cell] = _random_value()
	var visible := _visible_pairs()
	if visible.is_empty():
		_force_visible_pair()
		visible = _visible_pairs()
	var pair: Vector2i = visible[_rng.randi_range(0, visible.size() - 1)]
	var a := _rng.randi_range(maxi(MIN_VALUE, target - MAX_VALUE), mini(MAX_VALUE, target - MIN_VALUE))
	grid[pair.x] = a
	grid[pair.y] = target - a


## No two numbers see each other (tiny boards): move one number next to another.
func _force_visible_pair() -> void:
	var filled := _filled_cells()
	if filled.size() < 2:
		return
	var anchor := filled[0]
	var mover := filled[1]
	for neighbour in _neighbours(anchor):
		if grid[neighbour] == 0:
			grid[neighbour] = grid[mover]
			grid[mover] = 0
			return


func _neighbours(cell: int) -> Array[int]:
	var cells: Array[int] = []
	var cx := cell % size
	var cy := cell / size
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := cx + dx
			var y := cy + dy
			if (dx != 0 or dy != 0) and x >= 0 and x < size and y >= 0 and y < size:
				cells.append(y * size + x)
	return cells


## A new target that some visible pair already satisfies, different from the
## current one when possible.
func _pick_dynamic_target() -> void:
	var sums: Array[int] = []
	for pair in _visible_pairs():
		var total: int = grid[pair.x] + grid[pair.y]
		if total >= DYNAMIC_MIN and total <= DYNAMIC_MAX and total != target and not sums.has(total):
			sums.append(total)
	if sums.is_empty():
		return
	target = sums[_rng.randi_range(0, sums.size() - 1)]
