## Accumulates per-frame distances for tracking drills (mean, max, RMS).
class_name TrackingStats
extends RefCounted

var samples: int = 0
var sum: float = 0.0
var sum_squares: float = 0.0
var max_distance: float = 0.0


func add(distance: float) -> void:
	samples += 1
	sum += distance
	sum_squares += distance * distance
	max_distance = maxf(max_distance, distance)


func mean() -> float:
	return sum / samples if samples > 0 else 0.0


func rms() -> float:
	return sqrt(sum_squares / samples) if samples > 0 else 0.0
