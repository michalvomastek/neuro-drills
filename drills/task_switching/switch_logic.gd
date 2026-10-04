## Task switching: a digit with a task cue. Parity task: odd = left, even = right.
## Magnitude task: less than 5 = left, more than 5 = right. Tasks switch at random.
class_name SwitchLogic
extends RefCounted

enum Task { PARITY, MAGNITUDE }

const SWITCH_RATIO := 0.5

var trials: int
var digits: Array[int] = []
var tasks: Array[Task] = []
var current: int = 0
var repeat_stats := ReactionStats.new()
var switch_stats := ReactionStats.new()
var wrong_count: int = 0


func _init(p_trials: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	var task := Task.PARITY if rng.randi_range(0, 1) == 0 else Task.MAGNITUDE
	for i in trials:
		var digit := rng.randi_range(1, 8)
		if digit >= 5:
			digit += 1
		digits.append(digit)
		if i > 0 and rng.randf() < SWITCH_RATIO:
			task = Task.MAGNITUDE if task == Task.PARITY else Task.PARITY
		tasks.append(task)


func current_digit() -> int:
	return digits[current]


func current_task() -> Task:
	return tasks[current]


func is_switch(index: int) -> bool:
	return index > 0 and tasks[index] != tasks[index - 1]


## Correct side (0 = left, 1 = right) for trial [param index].
func correct_side(index: int) -> int:
	if tasks[index] == Task.PARITY:
		return 0 if digits[index] % 2 == 1 else 1
	return 0 if digits[index] < 5 else 1


func record_response(side: int, rt_ms: int) -> bool:
	var correct := side == correct_side(current)
	if correct:
		if is_switch(current):
			switch_stats.add(rt_ms)
		else:
			repeat_stats.add(rt_ms)
	else:
		wrong_count += 1
	current += 1
	return correct


func is_done() -> bool:
	return current >= trials


func accuracy() -> float:
	return float(trials - wrong_count) / trials if trials > 0 else 0.0


func switch_cost_ms() -> float:
	return switch_stats.mean() - repeat_stats.mean()


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(switch_stats.mean())
	result.error_count = wrong_count
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["RESULT_ACCURACY", Format.percent(accuracy())]),
		PackedStringArray(["SWITCH_RT_REPEAT", Format.millis(repeat_stats.mean())]),
		PackedStringArray(["SWITCH_RT_SWITCH", Format.millis(switch_stats.mean())]),
		PackedStringArray(["SWITCH_COST", Format.millis(switch_cost_ms())]),
	]
	result.details = {"repeat_ms": repeat_stats.times_ms.duplicate(), "switch_ms": switch_stats.times_ms.duplicate(), "wrong": wrong_count}
	result.metrics = {"switch_cost_ms": switch_cost_ms(), "error_rate": 1.0 - accuracy()}
	return result
