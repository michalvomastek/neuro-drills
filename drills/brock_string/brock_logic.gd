## Brock string: three beads at different depths; a cued bead shows a letter
## that has to be read, forcing focus jumps between near, middle and far.
class_name BrockLogic
extends RefCounted

const LETTERS := "ABCDEFHKLMNPRTUVXZ"
const OPTION_COUNT := 4
const DEPTHS: Array[float] = [-1.6, -4.0, -9.0]

var trials: int
var cue: Array[int] = []
var current: int = 0
var target: String = ""
var options: Array[String] = []
var distractors: Array[String] = []
var stats := ReactionStats.new()
var jump_stats := ReactionStats.new()
var wrong_count: int = 0
var _rng: RandomNumberGenerator


func _init(p_trials: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	_rng = rng
	var previous := -1
	for i in trials:
		var bead := _rng.randi_range(0, DEPTHS.size() - 1)
		if bead == previous:
			bead = (bead + 1 + _rng.randi_range(0, DEPTHS.size() - 2)) % DEPTHS.size()
		cue.append(bead)
		previous = bead


func current_bead() -> int:
	return cue[current]


## Whether the current trial jumps across the middle bead (near <-> far).
func is_long_jump() -> bool:
	return current > 0 and absi(cue[current] - cue[current - 1]) == 2


func new_trial() -> void:
	options.clear()
	while options.size() < OPTION_COUNT:
		var letter := LETTERS[_rng.randi_range(0, LETTERS.length() - 1)]
		if not options.has(letter):
			options.append(letter)
	target = options[_rng.randi_range(0, OPTION_COUNT - 1)]
	distractors.clear()
	for i in DEPTHS.size():
		var letter := LETTERS[_rng.randi_range(0, LETTERS.length() - 1)]
		while letter == target:
			letter = LETTERS[_rng.randi_range(0, LETTERS.length() - 1)]
		distractors.append(letter)


func letter_on(bead: int) -> String:
	return target if bead == cue[current] else distractors[bead]


func answer(letter: String, rt_ms: int) -> bool:
	var correct := letter == target
	if correct:
		stats.add(rt_ms)
		if is_long_jump():
			jump_stats.add(rt_ms)
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
		PackedStringArray(["BROCK_LONG_JUMP_RT", Format.millis(jump_stats.mean())]),
	]
	result.details = {"times_ms": stats.times_ms.duplicate(), "wrong": wrong_count}
	return result
