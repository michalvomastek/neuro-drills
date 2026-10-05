## RSVP reading: words of a passage shown one at a time at a fixed pace,
## followed by comprehension questions with several answers each.
class_name RsvpLogic
extends RefCounted

## Passages live in the translations as RSVP_TEXT_n with questions
## RSVP_Q_n_q and answers RSVP_A_n_q_k; the first answer is the correct one
## and the order is shuffled for every run.
const PASSAGE_COUNT := 12
const QUESTIONS_PER_PASSAGE := 2
const ANSWERS_PER_QUESTION := 4

var wpm: int
var passage_index: int
var words: PackedStringArray = PackedStringArray()
## Current question (0-based); equals QUESTIONS_PER_PASSAGE when all are answered.
var question: int = 0
var correct_count: int = 0
## Per question: the original answer index shown at each position.
var orders: Array[PackedInt32Array] = []


func _init(p_wpm: int, p_passage_index: int, translated_text: String, rng: RandomNumberGenerator = null) -> void:
	wpm = p_wpm
	passage_index = posmod(p_passage_index, PASSAGE_COUNT)
	for word in translated_text.split(" ", false):
		words.append(word.strip_edges())
	for q in QUESTIONS_PER_PASSAGE:
		var order := PackedInt32Array(range(ANSWERS_PER_QUESTION))
		if rng != null:
			for i in range(order.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var t := order[i]
				order[i] = order[j]
				order[j] = t
		orders.append(order)


## A passage index for this run, never the one played last ([param avoid] -1 for none).
static func pick_passage(rng: RandomNumberGenerator, avoid: int = -1) -> int:
	var index := rng.randi_range(0, PASSAGE_COUNT - 1)
	if index == avoid:
		index = (index + 1 + rng.randi_range(0, PASSAGE_COUNT - 2)) % PASSAGE_COUNT
	return index


static func text_key(index: int) -> String:
	return "RSVP_TEXT_%d" % (index + 1)


func seconds_per_word() -> float:
	return 60.0 / wpm


func is_done() -> bool:
	return question >= QUESTIONS_PER_PASSAGE


func question_key() -> String:
	return "RSVP_Q_%d_%d" % [passage_index + 1, question + 1]


## Answer keys of the current question in display order.
func answer_keys() -> Array[String]:
	var keys: Array[String] = []
	for original in orders[question]:
		keys.append("RSVP_A_%d_%d_%d" % [passage_index + 1, question + 1, original + 1])
	return keys


## Position of the correct answer in the current display order.
func correct_position() -> int:
	return orders[question].find(0)


## Records the answer at display [param position] and moves to the next
## question; returns whether it was correct.
func answer(position: int) -> bool:
	var correct := position == correct_position()
	if correct:
		correct_count += 1
	question += 1
	return correct


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(words.size() * seconds_per_word() * 1000.0)
	result.error_count = QUESTIONS_PER_PASSAGE - correct_count
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["RSVP_WPM", str(wpm)]),
		PackedStringArray(["RSVP_WORDS", str(words.size())]),
		PackedStringArray(["RSVP_COMPREHENSION", "%d / %d" % [correct_count, QUESTIONS_PER_PASSAGE]]),
	]
	result.details = {"wpm": wpm, "words": words.size(), "correct": correct_count, "questions": QUESTIONS_PER_PASSAGE}
	result.metrics = {"wpm": float(wpm), "comprehension": float(correct_count) / QUESTIONS_PER_PASSAGE}
	return result
