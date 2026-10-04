## Adaptive span bookkeeping shared by sequence-memory drills: the length grows
## after a correct round and the run ends after too many consecutive failures
## or at the maximum length.
class_name SpanTracker
extends RefCounted

var length: int
var max_length: int
var failures_allowed: int
## Longest length answered correctly.
var span: int = 0
var rounds: int = 0
var correct_rounds: int = 0
var done: bool = false
var _consecutive_failures: int = 0


func _init(start_length: int, p_max_length: int, p_failures_allowed: int = 2) -> void:
	length = start_length
	max_length = p_max_length
	failures_allowed = p_failures_allowed


func record(success: bool) -> void:
	if done:
		return
	rounds += 1
	if success:
		correct_rounds += 1
		span = maxi(span, length)
		_consecutive_failures = 0
		if length >= max_length:
			done = true
		else:
			length += 1
	else:
		_consecutive_failures += 1
		if _consecutive_failures >= failures_allowed:
			done = true
