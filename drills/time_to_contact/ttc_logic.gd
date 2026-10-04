## Time to contact: a ball flies towards the viewer under gravity, vanishes
## halfway, and the player presses when and where it would hit the screen
## plane. Camera at the origin looking down -Z; the impact plane is z = 0.
class_name TtcLogic
extends RefCounted

## Reduced gravity keeps the arc inside the 60-degree view.
const GRAVITY := 5.0
const START_DEPTH := 24.0
const IMPACT_Z := -1.5
const HIDE_FRACTION := 0.5
const RESPONSE_LIMIT_MS := 2500

var trials: int
var current: int = 0
var starts: Array[Vector3] = []
var velocities: Array[Vector3] = []
var time_errors_ms: Array[int] = []
## Distance between click and impact point, in units of the viewport height.
var position_errors: Array[float] = []
var _rng: RandomNumberGenerator


func _init(p_trials: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	_rng = rng
	for i in trials:
		var flight := _rng.randf_range(1.3, 2.1)
		var start := Vector3(_rng.randf_range(-3.0, 3.0), _rng.randf_range(0.5, 2.5), -START_DEPTH)
		# Choose the velocity so the ball lands inside the view on the impact plane.
		var target := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.55, 0.55), IMPACT_Z)
		var velocity := (target - start) / flight
		velocity.y += 0.5 * GRAVITY * flight
		starts.append(start)
		velocities.append(velocity)


func flight_seconds() -> float:
	return (IMPACT_Z - starts[current].z) / velocities[current].z


func position_at(seconds: float) -> Vector3:
	var p := starts[current] + velocities[current] * seconds
	p.y -= 0.5 * GRAVITY * seconds * seconds
	return p


func impact_point() -> Vector3:
	return position_at(flight_seconds())


func is_visible_at(seconds: float) -> bool:
	return position_at(seconds).z < -START_DEPTH * HIDE_FRACTION


## Records a press; returns the signed time error (negative = early).
func record(press_seconds: float, position_error: float) -> int:
	var error := roundi((press_seconds - flight_seconds()) * 1000.0)
	time_errors_ms.append(error)
	position_errors.append(position_error)
	current += 1
	return error


func is_done() -> bool:
	return current >= trials


func mean_abs_time_error_ms() -> float:
	if time_errors_ms.is_empty():
		return 0.0
	var sum := 0
	for e in time_errors_ms:
		sum += absi(e)
	return float(sum) / time_errors_ms.size()


func mean_position_error() -> float:
	if position_errors.is_empty():
		return 0.0
	var sum := 0.0
	for e in position_errors:
		sum += e
	return sum / position_errors.size()


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(mean_abs_time_error_ms())
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["ANTICIPATION_MEAN_ERROR", Format.millis(mean_abs_time_error_ms())]),
		PackedStringArray(["TTC_POSITION_ERROR", Format.percent(mean_position_error())]),
	]
	result.details = {"time_errors_ms": time_errors_ms.duplicate(), "position_errors": position_errors.duplicate()}
	return result
