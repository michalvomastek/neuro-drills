## Looming evasion: an obstacle grows towards the viewer from an off-centre
## direction; shift the view away before it fills the collision zone.
class_name LoomingLogic
extends RefCounted

const GROW_SECONDS := 2.2
const START_RADIUS := 0.03
const END_RADIUS := 0.26
const COLLISION_ZONE := 0.1
## Offsets of the obstacle's centre at full size, in units of the stage height.
const OFFSETS: Array[Vector2] = [
	Vector2(0.12, 0.0), Vector2(-0.12, 0.0), Vector2(0.0, 0.12), Vector2(0.0, -0.12),
	Vector2(0.09, 0.09), Vector2(-0.09, 0.09), Vector2(0.09, -0.09), Vector2(-0.09, -0.09),
]

var trials: int
var current: int = 0
var offsets: Array[Vector2] = []
var evaded: int = 0
var reaction_stats := ReactionStats.new()
var _rng: RandomNumberGenerator


func _init(p_trials: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	_rng = rng
	for i in trials:
		offsets.append(OFFSETS[_rng.randi_range(0, OFFSETS.size() - 1)])


func next_gap_ms() -> int:
	return _rng.randi_range(900, 2000)


func current_offset() -> Vector2:
	return offsets[current]


func radius_at(seconds: float) -> float:
	var t := clampf(seconds / GROW_SECONDS, 0.0, 1.0)
	return lerpf(START_RADIUS, END_RADIUS, t * t)


## Whether the obstacle, displaced by the player's [param shift], misses the viewer.
static func misses(offset: Vector2, shift: Vector2, radius: float) -> bool:
	return (offset - shift).length() > radius + COLLISION_ZONE


func record(did_evade: bool, first_move_ms: int) -> void:
	if did_evade:
		evaded += 1
		if first_move_ms >= 0:
			reaction_stats.add(first_move_ms)
	current += 1


func is_done() -> bool:
	return current >= trials


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(reaction_stats.mean())
	result.error_count = trials - evaded
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["LOOMING_EVADED", "%d / %d" % [evaded, trials]]),
		PackedStringArray(["LOOMING_FIRST_MOVE", Format.millis(reaction_stats.mean())]),
	]
	result.details = {"evaded": evaded, "first_move_ms": reaction_stats.times_ms.duplicate()}
	return result
