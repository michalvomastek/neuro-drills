## Mental rotation: a reference shape and a probe that is the same shape
## rotated, or its mirror image rotated. Decide whether they match.
class_name RotationLogic
extends RefCounted

## Asymmetric pentominoes as cell lists.
const SHAPES: Array[Array] = [
	[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3)],
	[Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, 3)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)],
	[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)],
]

var trials: int
var shape_index: Array[int] = []
var rotations: Array[int] = []
var mirrored: Array[bool] = []
var current: int = 0
var stats := ReactionStats.new()
var wrong_count: int = 0
var _rng: RandomNumberGenerator


func _init(p_trials: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	_rng = rng
	for i in trials:
		shape_index.append(_rng.randi_range(0, SHAPES.size() - 1))
		rotations.append(_rng.randi_range(1, 3))
		mirrored.append(i % 2 == 1)
	for i in range(trials - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var m := mirrored[i]
		mirrored[i] = mirrored[j]
		mirrored[j] = m


static func normalized(cells: Array[Vector2i]) -> Array[Vector2i]:
	var min_x := cells[0].x
	var min_y := cells[0].y
	for c in cells:
		min_x = mini(min_x, c.x)
		min_y = mini(min_y, c.y)
	var out: Array[Vector2i] = []
	for c in cells:
		out.append(Vector2i(c.x - min_x, c.y - min_y))
	out.sort()
	return out


## Rotates by [param quarter_turns] * 90 degrees, optionally mirrored first.
static func transform(cells: Array[Vector2i], quarter_turns: int, mirror: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		var p := Vector2i(-c.x, c.y) if mirror else c
		for t in quarter_turns % 4:
			p = Vector2i(-p.y, p.x)
		out.append(p)
	return normalized(out)


func reference_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(SHAPES[shape_index[current]])
	return normalized(cells)


func probe_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(SHAPES[shape_index[current]])
	return transform(cells, rotations[current], mirrored[current])


## [param says_same] is the player's answer; returns whether it was right.
func answer(says_same: bool, rt_ms: int) -> bool:
	var correct := says_same != mirrored[current]
	if correct:
		stats.add(rt_ms)
	else:
		wrong_count += 1
	current += 1
	return correct


func is_done() -> bool:
	return current >= trials


func accuracy() -> float:
	return float(trials - wrong_count) / trials if trials > 0 else 0.0


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(stats.median())
	result.error_count = wrong_count
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["RESULT_ACCURACY", Format.percent(accuracy())]),
		PackedStringArray(["RESULT_MEDIAN_RT", Format.millis(stats.median())]),
		PackedStringArray(["RESULT_WRONG", str(wrong_count)]),
	]
	result.details = {"times_ms": stats.times_ms.duplicate(), "wrong": wrong_count}
	return result
