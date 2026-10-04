## Multiple object tracking: identical discs move and bounce inside a unit
## square; a few were marked as targets at the start and must be picked out.
class_name MotLogic
extends RefCounted

const BALL_COUNT := 10
const TARGET_COUNT := 3
const RADIUS := 0.045
const SPEED := 0.22
const SHOW_SECONDS := 1.5
const MOVE_SECONDS := 6.0

var rounds: int
var round_index: int = 0
var positions: Array[Vector2] = []
var velocities: Array[Vector2] = []
var targets: Array[int] = []
var selected: Array[int] = []
var correct_total: int = 0
var _rng: RandomNumberGenerator


func _init(p_rounds: int, rng: RandomNumberGenerator) -> void:
	rounds = p_rounds
	_rng = rng


## Places the discs without overlap and picks the targets.
func new_round() -> void:
	positions.clear()
	velocities.clear()
	selected.clear()
	while positions.size() < BALL_COUNT:
		var candidate := Vector2(_rng.randf_range(RADIUS, 1.0 - RADIUS), _rng.randf_range(RADIUS, 1.0 - RADIUS))
		var clear := true
		for other in positions:
			if other.distance_to(candidate) < RADIUS * 2.5:
				clear = false
				break
		if clear:
			positions.append(candidate)
			var angle := _rng.randf_range(0.0, TAU)
			velocities.append(Vector2(cos(angle), sin(angle)) * SPEED)
	targets.clear()
	var pool: Array[int] = []
	for i in BALL_COUNT:
		pool.append(i)
	for i in TARGET_COUNT:
		targets.append(pool.pop_at(_rng.randi_range(0, pool.size() - 1)))


## Advances the motion by [param dt] seconds with wall and disc bounces.
func step(dt: float) -> void:
	for i in positions.size():
		positions[i] += velocities[i] * dt
		if positions[i].x < RADIUS or positions[i].x > 1.0 - RADIUS:
			velocities[i].x = -velocities[i].x
			positions[i].x = clampf(positions[i].x, RADIUS, 1.0 - RADIUS)
		if positions[i].y < RADIUS or positions[i].y > 1.0 - RADIUS:
			velocities[i].y = -velocities[i].y
			positions[i].y = clampf(positions[i].y, RADIUS, 1.0 - RADIUS)
	for i in positions.size():
		for j in range(i + 1, positions.size()):
			var delta := positions[j] - positions[i]
			var distance := delta.length()
			if distance < RADIUS * 2.0 and distance > 0.0:
				var normal := delta / distance
				var relative := velocities[i] - velocities[j]
				if relative.dot(normal) > 0.0:
					velocities[i] -= normal * relative.dot(normal)
					velocities[j] += normal * relative.dot(normal)
				var push := (RADIUS * 2.0 - distance) * 0.5
				positions[i] -= normal * push
				positions[j] += normal * push


## Index of the disc under [param point], or -1.
func ball_at(point: Vector2) -> int:
	var best := -1
	var best_distance := RADIUS * 1.6
	for i in positions.size():
		var distance := positions[i].distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


## Toggles a pick; returns false when the pick was rejected (already full).
func select(index: int) -> bool:
	if selected.has(index):
		selected.erase(index)
		return true
	if selected.size() >= TARGET_COUNT:
		return false
	selected.append(index)
	return true


func is_round_complete() -> bool:
	return selected.size() >= TARGET_COUNT


## Scores the round; returns how many picks were targets.
func finish_round() -> int:
	var correct := 0
	for pick in selected:
		if targets.has(pick):
			correct += 1
	correct_total += correct
	round_index += 1
	return correct


func is_done() -> bool:
	return round_index >= rounds


func accuracy() -> float:
	return float(correct_total) / (rounds * TARGET_COUNT) if rounds > 0 else 0.0


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.error_count = rounds * TARGET_COUNT - correct_total
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["MOT_TRACKED", "%d / %d" % [correct_total, rounds * TARGET_COUNT]]),
		PackedStringArray(["RESULT_ACCURACY", Format.percent(accuracy())]),
	]
	result.details = {"correct": correct_total, "rounds": rounds}
	result.metrics = {"accuracy": accuracy()}
	return result
