## Sum pairs: numbers 1-9 sit on a partly filled grid; two (or, with chains,
## more) numbers whose sum is the target are removed when they are joined
## along a row or a column with no other number in between. Removed numbers
## are replaced elsewhere, so the board keeps its density, and the target
## changes after every join to a sum the board already offers (the
## maintainer's play test: a fixed target played worse and generated
## worse). Timed run. Pure logic: the scene only taps.
class_name SumPairsLogic
extends RefCounted

enum Outcome { IGNORED, SELECTED, DESELECTED, COMPLETED, BLOCKED, WRONG_SUM }

const MIN_VALUE := 1
const MAX_VALUE := 9
## Share of the cells that hold a number; the empty cells are what makes a
## line of sight matter.
const DENSITY := 0.6
const TARGET_MIN := 6
const TARGET_MAX := 14
const ENSURE_ATTEMPTS := 40
## Valid pairs the board keeps at least after every move: a single one is
## too easy to miss under time pressure.
const MIN_PAIRS := 2

var size: int
var target: int = 0
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


func _init(p_size: int, p_chains: bool, rng: RandomNumberGenerator) -> void:
	size = p_size
	chains = p_chains
	_rng = rng
	grid.resize(size * size)
	grid.fill(0)
	_refill(number_count())
	_next_target()


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


## True when the two cells share a row or a column and no number lies
## between them (the maintainer tried diagonals and free angles: a tap-tap
## game on a phone reads best with straight rows and columns).
func line_clear(a: int, b: int) -> bool:
	if a == b or not aligned(a, b):
		return false
	for cell in cells_between(a, b):
		if grid[cell] != 0:
			return false
	return true


## The cells strictly between [param a] and [param b] along their shared row
## or column; empty when the two cells share neither.
func cells_between(a: int, b: int) -> Array[int]:
	var cells: Array[int] = []
	var ax := a % size
	var ay := a / size
	var bx := b % size
	var by := b / size
	if ax != bx and ay != by:
		return cells
	var step := 1 if ay == by else size
	var low := mini(a, b)
	var high := maxi(a, b)
	var cell := low + step
	while cell < high:
		cells.append(cell)
		cell += step
	return cells


## True when the two cells lie in one row or one column.
func aligned(a: int, b: int) -> bool:
	return a % size == b % size or a / size == b / size


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


## Numbered cells that take part in none of [param pairs]; re-rolling them
## cannot break a pair the player may already be looking at.
func unpaired_cells(pairs: Array[Vector2i]) -> Array[int]:
	var paired: Array[int] = []
	for pair in pairs:
		if not paired.has(pair.x):
			paired.append(pair.x)
		if not paired.has(pair.y):
			paired.append(pair.y)
	var cells: Array[int] = []
	for cell in _filled_cells():
		if not paired.has(cell):
			cells.append(cell)
	return cells


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
	var cleared := selection.duplicate()
	selection.clear()
	_refill(removed, cleared)
	_next_target()


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


func _random_value() -> int:
	return _rng.randi_range(MIN_VALUE, MAX_VALUE)


## A value that has a partner within 1-9 for the current target.
func _pairable_value() -> int:
	return _rng.randi_range(maxi(MIN_VALUE, target - MAX_VALUE), mini(MAX_VALUE, target - MIN_VALUE))


## New numbers go to empty cells other than the ones just cleared, so a
## joined number never seems to come straight back.
func _refill(count: int, avoid: Array[int] = []) -> void:
	var empty := _empty_cells()
	if empty.size() - avoid.size() >= count:
		for cell in avoid:
			empty.erase(cell)
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


## Keeps MIN_PAIRS valid pairs for the current target whenever the numbers
## allow it: re-rolls numbers that are in no valid pair, then rewrites
## visible pairs made of such numbers, so an existing pair is never broken.
## Bounded: a board too small or too full to hold two pairs keeps what it has.
func _ensure_move() -> void:
	for _attempt in ENSURE_ATTEMPTS:
		var pairs := valid_pairs()
		if pairs.size() >= MIN_PAIRS:
			return
		var free := unpaired_cells(pairs)
		if free.is_empty():
			return
		var candidates: Array[Vector2i] = []
		for pair in _visible_pairs():
			if free.has(pair.x) and free.has(pair.y):
				candidates.append(pair)
		if candidates.is_empty() and pairs.is_empty():
			_force_visible_pair()
			continue
		if candidates.is_empty() or _attempt < ENSURE_ATTEMPTS / 2:
			grid[free[_rng.randi_range(0, free.size() - 1)]] = _random_value()
		else:
			var pair: Vector2i = candidates[_rng.randi_range(0, candidates.size() - 1)]
			var value := _pairable_value()
			grid[pair.x] = value
			grid[pair.y] = target - value


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
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var x := cx + offset.x
		var y := cy + offset.y
		if x >= 0 and x < size and y >= 0 and y < size:
			cells.append(y * size + x)
	return cells


## The next target: a sum between TARGET_MIN and TARGET_MAX that the visible
## pairs already offer, preferring one with MIN_PAIRS pairs and one different
## from the current target; then the board is topped up to MIN_PAIRS pairs.
func _next_target() -> void:
	var counts: Dictionary = {}
	for pair in _visible_pairs():
		var total: int = grid[pair.x] + grid[pair.y]
		if total >= TARGET_MIN and total <= TARGET_MAX:
			var seen: int = counts.get(total, 0)
			counts[total] = seen + 1
	var rich: Array[int] = []
	var any: Array[int] = []
	for sum: int in counts:
		if sum == target:
			continue
		any.append(sum)
		var count: int = counts[sum]
		if count >= MIN_PAIRS:
			rich.append(sum)
	var pool := rich if not rich.is_empty() else any
	if pool.is_empty():
		if target == 0:
			target = _rng.randi_range(TARGET_MIN, TARGET_MAX)
	else:
		target = pool[_rng.randi_range(0, pool.size() - 1)]
	_ensure_move()
