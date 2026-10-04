## SART (Sustained Attention to Response Task): respond to every digit except 3.
class_name SartLogic
extends RefCounted

const NO_GO_DIGIT := 3
const STIMULUS_MS := 250
const INTERVAL_MS := 1150

var trials: int
var digits: Array[int] = []
var current: int = 0
var go_stats := ReactionStats.new()
var omissions: int = 0
var commissions: int = 0
var _responded: bool = false


func _init(p_trials: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	# Balanced digits 1..9, then shuffled.
	for i in trials:
		digits.append(i % 9 + 1)
	for i in range(digits.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := digits[i]
		digits[i] = digits[j]
		digits[j] = swap


func current_digit() -> int:
	return digits[current]


func current_is_go() -> bool:
	return digits[current] != NO_GO_DIGIT


## First response inside the current window; returns whether it was correct.
func respond(rt_ms: int) -> bool:
	if _responded:
		return current_is_go()
	_responded = true
	if current_is_go():
		go_stats.add(rt_ms)
		return true
	commissions += 1
	return false


## Closes the current window and moves on.
func close_window() -> void:
	if current_is_go() and not _responded:
		omissions += 1
	_responded = false
	current += 1


func is_done() -> bool:
	return current >= trials


func no_go_count() -> int:
	var count := 0
	for d in digits:
		if d == NO_GO_DIGIT:
			count += 1
	return count


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(go_stats.mean())
	result.error_count = omissions + commissions
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["SART_COMMISSIONS", "%d / %d" % [commissions, no_go_count()]]),
		PackedStringArray(["SART_OMISSIONS", str(omissions)]),
		PackedStringArray(["RESULT_MEAN_RT", Format.millis(go_stats.mean())]),
		PackedStringArray(["RESULT_RT_SD", Format.millis(go_stats.std_dev())]),
	]
	result.details = {"commissions": commissions, "omissions": omissions, "go_times_ms": go_stats.times_ms.duplicate()}
	return result
