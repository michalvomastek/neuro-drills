## Peripheral reading: letters stream in the centre (count the target letter)
## while discs pass along both sides (count the red ones).
class_name ReadingLogic
extends RefCounted

const LETTERS := "ABDEFGHKLMNPRSTUVXZ"
const LETTER_MS := 550
const RED_RATIO := 0.35

var letter_count: int
var target_letter: String
var letters: Array[String] = []
var target_occurrences: int = 0
## One disc per letter step, alternating sides; true = red.
var disc_is_red: Array[bool] = []
var red_count: int = 0
var reported_letters: int = -1
var reported_red: int = -1
var _rng: RandomNumberGenerator


func _init(p_letter_count: int, rng: RandomNumberGenerator) -> void:
	letter_count = p_letter_count
	_rng = rng
	target_letter = LETTERS[_rng.randi_range(0, LETTERS.length() - 1)]
	for i in letter_count:
		var letter := target_letter if _rng.randf() < 0.25 else LETTERS[_rng.randi_range(0, LETTERS.length() - 1)]
		letters.append(letter)
		if letter == target_letter:
			target_occurrences += 1
		var red := _rng.randf() < RED_RATIO
		disc_is_red.append(red)
		if red:
			red_count += 1


func report(letters_seen: int, reds_seen: int) -> void:
	reported_letters = letters_seen
	reported_red = reds_seen


func letters_correct() -> bool:
	return reported_letters == target_occurrences


func reds_correct() -> bool:
	return reported_red == red_count


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.error_count = (0 if letters_correct() else 1) + (0 if reds_correct() else 1)
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["READING_LETTERS", "%d / %d" % [reported_letters, target_occurrences]]),
		PackedStringArray(["READING_REDS", "%d / %d" % [reported_red, red_count]]),
	]
	result.details = {"target": target_letter, "occurrences": target_occurrences, "reds": red_count, "reported_letters": reported_letters, "reported_red": reported_red}
	return result
