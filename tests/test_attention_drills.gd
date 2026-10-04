extends TestCase


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_trail_labels_and_order() -> void:
	var a := TrailLogic.new(10, false, _rng(1))
	assert_eq(a.labels, ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"] as Array[String])
	assert_eq(a.positions.size(), 10)
	for p in a.positions:
		assert_true(p.x >= 0.0 and p.x <= 1.0 and p.y >= 0.0 and p.y <= 1.0)
	var b := TrailLogic.new(8, true, _rng(1))
	assert_eq(b.labels, ["1", "A", "2", "B", "3", "C", "4", "D"] as Array[String])
	assert_false(b.register_click(1, 100))
	assert_eq(b.error_count, 1)
	for i in 8:
		b.register_click(i, (i + 1) * 100)
	assert_true(b.finished)
	assert_eq(b.total_time_ms(), 800)
	assert_false(b.register_click(0, 900))


func test_search_target_and_scoring() -> void:
	var logic := SearchLogic.new(5, 16, _rng(2))
	var target := logic.target_index[0]
	var distractors := 0
	for i in 16:
		if logic.letter_at(i) == logic.distractor_letter[0]:
			distractors += 1
	assert_eq(distractors, 15)
	assert_ne(logic.letter_at(target), logic.distractor_letter[0])
	assert_false(logic.record_click((target + 1) % 16, 500))
	assert_eq(logic.current, 0)
	assert_true(logic.record_click(target, 600))
	assert_eq(logic.current, 1)
	assert_eq(logic.wrong_count, 1)


func test_sart_balanced_digits_and_errors() -> void:
	var logic := SartLogic.new(45, _rng(3))
	assert_eq(logic.no_go_count(), 5)
	var commissions := 0
	var omissions := 0
	for i in 45:
		if i % 3 == 0:
			# Respond on every third trial regardless of digit.
			if not logic.respond(300):
				commissions += 1
		elif logic.current_is_go():
			omissions += 1
		logic.close_window()
	assert_true(logic.is_done())
	assert_eq(logic.commissions, commissions)
	assert_eq(logic.omissions, omissions)
	assert_eq(logic.go_stats.count(), 15 - commissions)


func test_switch_rules_and_cost() -> void:
	var logic := SwitchLogic.new(40, _rng(4))
	var switches := 0
	for i in 40:
		assert_ne(logic.digits[i], 5)
		if logic.is_switch(i):
			switches += 1
		var side := logic.correct_side(i)
		if logic.tasks[i] == SwitchLogic.Task.PARITY:
			assert_eq(side, 0 if logic.digits[i] % 2 == 1 else 1)
		else:
			assert_eq(side, 0 if logic.digits[i] < 5 else 1)
		logic.record_response(side, 800 if logic.is_switch(i) else 600)
	assert_true(switches > 0 and switches < 40)
	assert_eq(logic.accuracy(), 1.0)
	assert_eq(logic.switch_cost_ms(), 200.0)


func test_rsvp_words_and_answer() -> void:
	var logic := RsvpLogic.new(300, 1, "one two  three four")
	assert_eq(logic.words.size(), 4)
	assert_eq(logic.seconds_per_word(), 0.2)
	assert_true(logic.answer(0))
	assert_false(RsvpLogic.new(300, 1, "a b").answer(2))
	assert_eq(logic.build_result(&"rsvp_reading", {}).total_ms, 800)


func test_pyramid_distance_adapts() -> void:
	var logic := PyramidLogic.new(3, _rng(5))
	logic.new_round()
	assert_ne(logic.left, logic.right)
	assert_true(logic.check(logic.left, logic.right))
	assert_true(is_equal_approx(logic.distance, PyramidLogic.START_DISTANCE + PyramidLogic.STEP))
	logic.new_round()
	assert_false(logic.check(logic.left, (logic.right + 1) % 10))
	assert_true(is_equal_approx(logic.distance, PyramidLogic.START_DISTANCE))
	logic.new_round()
	logic.check(logic.left, logic.right)
	assert_true(logic.is_done())
	# The largest width is the one at which an answer was correct, i.e. the starting distance.
	assert_true(is_equal_approx(logic.max_distance, PyramidLogic.START_DISTANCE))


func test_flash_number_length_follows_tracker() -> void:
	var logic := FlashLogic.new(_rng(6))
	var number := logic.new_round()
	assert_eq(number.length(), FlashLogic.START_DIGITS)
	assert_ne(number[0], "0")
	assert_true(logic.check(number))
	assert_eq(logic.new_round().length(), FlashLogic.START_DIGITS + 1)
	assert_false(logic.check("1"))
	assert_false(logic.check("1"))
	assert_true(logic.tracker.done)
	assert_eq(logic.tracker.span, FlashLogic.START_DIGITS)


func test_arithmetic_solutions() -> void:
	var logic := ArithmeticLogic.new(60, _rng(7))
	for i in 30:
		logic.new_problem()
		var expected := 0
		match logic.op:
			ArithmeticLogic.Op.ADD:
				expected = logic.a + logic.b
			ArithmeticLogic.Op.SUB:
				expected = logic.a - logic.b
				assert_true(expected > 0)
			ArithmeticLogic.Op.MUL:
				expected = logic.a * logic.b
		assert_eq(logic.solution(), expected)
		assert_true(logic.check(expected, 1000))
	assert_false(logic.check(logic.solution() + 1, 1000))
	assert_eq(logic.correct_count, 30)
	assert_eq(logic.wrong_count, 1)
