## RSVP reading: words of a passage shown one at a time at a fixed pace,
## followed by one comprehension question.
class_name RsvpLogic
extends RefCounted

## Passages are translation keys: text, question, three answers and the correct answer index.
const PASSAGES: Array[Dictionary] = [
	{"text": "RSVP_TEXT_1", "question": "RSVP_Q_1", "answers": ["RSVP_A_1_1", "RSVP_A_1_2", "RSVP_A_1_3"], "correct": 1},
	{"text": "RSVP_TEXT_2", "question": "RSVP_Q_2", "answers": ["RSVP_A_2_1", "RSVP_A_2_2", "RSVP_A_2_3"], "correct": 0},
	{"text": "RSVP_TEXT_3", "question": "RSVP_Q_3", "answers": ["RSVP_A_3_1", "RSVP_A_3_2", "RSVP_A_3_3"], "correct": 2},
]

var wpm: int
var passage: Dictionary
var words: PackedStringArray = PackedStringArray()
var answered_correctly: bool = false
var answered: bool = false


func _init(p_wpm: int, passage_index: int, translated_text: String) -> void:
	wpm = p_wpm
	passage = PASSAGES[passage_index % PASSAGES.size()]
	for word in translated_text.split(" ", false):
		words.append(word.strip_edges())


static func pick_passage(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, PASSAGES.size() - 1)


func seconds_per_word() -> float:
	return 60.0 / wpm


func answer(index: int) -> bool:
	answered = true
	var correct_index: int = passage["correct"]
	answered_correctly = index == correct_index
	return answered_correctly


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(words.size() * seconds_per_word() * 1000.0)
	result.error_count = 0 if answered_correctly else 1
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["RSVP_WPM", str(wpm)]),
		PackedStringArray(["RSVP_WORDS", str(words.size())]),
		PackedStringArray(["RSVP_COMPREHENSION", "RSVP_CORRECT" if answered_correctly else "RSVP_WRONG"]),
	]
	result.details = {"wpm": wpm, "words": words.size(), "correct": answered_correctly}
	return result
