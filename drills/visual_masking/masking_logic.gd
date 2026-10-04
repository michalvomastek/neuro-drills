## Backward masking: a letter shows very briefly and is covered by a mask; the
## exposure adapts towards the shortest duration still recognised.
class_name MaskingLogic
extends RefCounted

const LETTERS := "ABCDEFGHKLMNPRSTUVXZ"
const OPTION_COUNT := 4
const START_MS := 120.0
const MIN_MS := 16.0
const MAX_MS := 400.0
const STEP_DOWN_MS := 12.0
const STEP_UP_MS := 24.0
const MASK_MS := 300

var trials: int
var staircase := Staircase.new(START_MS, MIN_MS, MAX_MS, STEP_DOWN_MS, STEP_UP_MS)
var current: int = 0
var correct_count: int = 0
var target: String = ""
var options: Array[String] = []
var _rng: RandomNumberGenerator


func _init(p_trials: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	_rng = rng


func exposure_ms() -> float:
	return staircase.value


## Picks a target letter and three distinct distractors, shuffled.
func new_trial() -> void:
	options.clear()
	while options.size() < OPTION_COUNT:
		var letter := LETTERS[_rng.randi_range(0, LETTERS.length() - 1)]
		if not options.has(letter):
			options.append(letter)
	target = options[_rng.randi_range(0, OPTION_COUNT - 1)]


func mask_text() -> String:
	var glyphs := "▓▒░#%&"
	var text := ""
	for i in 3:
		text += glyphs[_rng.randi_range(0, glyphs.length() - 1)]
	return text


func answer(letter: String) -> bool:
	var correct := letter == target
	if correct:
		correct_count += 1
	staircase.record(correct)
	current += 1
	return correct


func is_done() -> bool:
	return current >= trials


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(staircase.best) if staircase.has_threshold() else 0
	result.error_count = trials - correct_count
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["MASKING_THRESHOLD", Format.millis(staircase.best) if staircase.has_threshold() else "–"]),
		PackedStringArray(["RESULT_ACCURACY", Format.percent(float(correct_count) / trials if trials > 0 else 0.0)]),
		PackedStringArray(["STAIRCASE_FINAL", Format.millis(staircase.value)]),
	]
	result.details = {"threshold_ms": staircase.best if staircase.has_threshold() else -1, "correct": correct_count}
	result.metrics = {"threshold_ms": staircase.best if staircase.has_threshold() else -1.0}
	return result
