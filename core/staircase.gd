## Adaptive staircase: a value (duration, interval, contrast) gets harder after
## a correct answer and easier after a wrong one, converging on a threshold.
class_name Staircase
extends RefCounted

var value: float
var min_value: float
var max_value: float
var step_down: float
var step_up: float
## Hardest value at which an answer was correct (the measured threshold).
var best: float = INF
var reversals: int = 0
var _last_direction: int = 0


func _init(start: float, p_min: float, p_max: float, p_step_down: float, p_step_up: float) -> void:
	value = start
	min_value = p_min
	max_value = p_max
	step_down = p_step_down
	step_up = p_step_up


func record(correct: bool) -> void:
	var direction := -1 if correct else 1
	if _last_direction != 0 and direction != _last_direction:
		reversals += 1
	_last_direction = direction
	if correct:
		best = minf(best, value)
		value = maxf(min_value, value - step_down)
	else:
		value = minf(max_value, value + step_up)


func has_threshold() -> bool:
	return best != INF
