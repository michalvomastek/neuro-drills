## 3D mental rotation with Shepard-Metzler style cube figures: the probe is
## the reference rotated in space, or its mirror image rotated.
class_name Rotation3DLogic
extends RefCounted

## Chiral arm figures as cube offsets.
const SHAPES: Array[Array] = [
	[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(2, 1, 0), Vector3i(2, 2, 0), Vector3i(2, 2, 1), Vector3i(2, 2, 2), Vector3i(3, 2, 2)],
	[Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 2, 0), Vector3i(1, 2, 0), Vector3i(2, 2, 0), Vector3i(2, 2, 1), Vector3i(2, 3, 1), Vector3i(2, 4, 1)],
	[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 1, 0), Vector3i(1, 2, 0), Vector3i(1, 2, 1), Vector3i(1, 2, 2), Vector3i(0, 2, 2), Vector3i(0, 3, 2)],
	[Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, 2), Vector3i(1, 0, 2), Vector3i(2, 0, 2), Vector3i(2, 1, 2), Vector3i(2, 2, 2), Vector3i(2, 2, 3)],
]

var trials: int
var shape_index: Array[int] = []
var rotations: Array[Vector3] = []
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
		rotations.append(Vector3(
			deg_to_rad(_rng.randi_range(1, 3) * 90.0 + _rng.randf_range(-20.0, 20.0)),
			deg_to_rad(_rng.randi_range(0, 3) * 90.0 + _rng.randf_range(-20.0, 20.0)),
			deg_to_rad(_rng.randf_range(-30.0, 30.0))))
		mirrored.append(i % 2 == 1)
	for i in range(trials - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var m := mirrored[i]
		mirrored[i] = mirrored[j]
		mirrored[j] = m


func reference_cubes() -> Array[Vector3i]:
	var cubes: Array[Vector3i] = []
	cubes.assign(SHAPES[shape_index[current]])
	return cubes


## Cube offsets of the probe before rotation (mirrored along X when needed).
func probe_cubes() -> Array[Vector3i]:
	var cubes: Array[Vector3i] = []
	for c in reference_cubes():
		cubes.append(Vector3i(-c.x, c.y, c.z) if mirrored[current] else c)
	return cubes


func probe_rotation() -> Vector3:
	return rotations[current]


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
	result.metrics = {"median_rt_ms": stats.median(), "accuracy": accuracy()}
	return result
