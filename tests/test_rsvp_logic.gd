extends TestCase


func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


func test_two_questions_four_shuffled_answers() -> void:
	var logic := RsvpLogic.new(400, 3, "a b c d e", _rng(7))
	assert_eq(logic.words.size(), 5)
	assert_eq(logic.question_key(), "RSVP_Q_4_1")
	var keys := logic.answer_keys()
	assert_eq(keys.size(), RsvpLogic.ANSWERS_PER_QUESTION)
	var sorted := keys.duplicate()
	sorted.sort()
	assert_eq(sorted, ["RSVP_A_4_1_1", "RSVP_A_4_1_2", "RSVP_A_4_1_3", "RSVP_A_4_1_4"])
	assert_eq(keys[logic.correct_position()], "RSVP_A_4_1_1")
	assert_true(logic.answer(logic.correct_position()))
	assert_false(logic.is_done())
	assert_eq(logic.question_key(), "RSVP_Q_4_2")
	var wrong := (logic.correct_position() + 1) % RsvpLogic.ANSWERS_PER_QUESTION
	assert_false(logic.answer(wrong))
	assert_true(logic.is_done())
	var result := logic.build_result(&"rsvp_reading", {"wpm": 400})
	assert_eq(result.error_count, 1)
	assert_eq(result.metrics["comprehension"], 0.5)
	assert_eq(result.metrics["wpm"], 400.0)
	assert_eq(result.summary_rows[2][1], "1 / 2")


func test_pick_passage_avoids_the_last_one() -> void:
	var rng := _rng(3)
	for i in 200:
		var index := RsvpLogic.pick_passage(rng, 5)
		assert_true(index != 5 and index >= 0 and index < RsvpLogic.PASSAGE_COUNT)


func test_every_passage_has_its_texts() -> void:
	TranslationServer.set_locale("cs")
	for n in range(1, RsvpLogic.PASSAGE_COUNT + 1):
		assert_true(TranslationServer.translate("RSVP_TEXT_%d" % n) != "RSVP_TEXT_%d" % n, "text %d" % n)
		for q in range(1, RsvpLogic.QUESTIONS_PER_PASSAGE + 1):
			assert_true(TranslationServer.translate("RSVP_Q_%d_%d" % [n, q]) != "RSVP_Q_%d_%d" % [n, q], "question %d/%d" % [n, q])
			for k in range(1, RsvpLogic.ANSWERS_PER_QUESTION + 1):
				var key := "RSVP_A_%d_%d_%d" % [n, q, k]
				assert_true(TranslationServer.translate(key) != key, key)
