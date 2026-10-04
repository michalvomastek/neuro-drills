extends TestCase


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_span_tracker_grows_and_stops() -> void:
	var tracker := SpanTracker.new(3, 5)
	tracker.record(true)
	assert_eq(tracker.length, 4)
	assert_eq(tracker.span, 3)
	tracker.record(false)
	assert_eq(tracker.length, 4)
	assert_false(tracker.done)
	tracker.record(true)
	assert_eq(tracker.span, 4)
	tracker.record(false)
	tracker.record(false)
	assert_true(tracker.done)
	assert_eq(tracker.rounds, 5)
	assert_eq(tracker.correct_rounds, 2)
	var capped := SpanTracker.new(5, 5)
	capped.record(true)
	assert_true(capped.done)
	assert_eq(capped.span, 5)


func test_n_back_targets_and_scoring() -> void:
	var logic := NBackLogic.new(2, 30, _rng(11))
	assert_eq(logic.positions.size(), 30)
	var targets := logic.target_count()
	assert_true(targets > 0 and targets < 30)
	assert_false(logic.is_target(0))
	assert_false(logic.is_target(1))
	for i in 30:
		if logic.is_target(i):
			logic.respond(i)
		logic.evaluate(i)
	assert_true(logic.is_done())
	assert_eq(logic.hits, targets)
	assert_eq(logic.misses, 0)
	assert_eq(logic.false_alarms, 0)
	assert_eq(logic.accuracy(), 1.0)
	var sloppy := NBackLogic.new(1, 10, _rng(2))
	sloppy.respond(0)
	sloppy.evaluate(0)
	assert_eq(sloppy.false_alarms, 1)


func test_corsi_sequences_follow_tracker() -> void:
	var logic := CorsiLogic.new(_rng(3))
	var first := logic.new_sequence()
	assert_eq(first.size(), CorsiLogic.START_LENGTH)
	for i in range(1, first.size()):
		assert_ne(first[i], first[i - 1])
	assert_true(logic.check(first.duplicate()))
	var second := logic.new_sequence()
	assert_eq(second.size(), CorsiLogic.START_LENGTH + 1)
	var wrong: Array[int] = second.duplicate()
	wrong.reverse()
	if wrong != second:
		assert_false(logic.check(wrong))
	assert_eq(logic.tracker.span, CorsiLogic.START_LENGTH)


func test_digit_span_backward_expectation() -> void:
	var logic := DigitSpanLogic.new(true, _rng(8))
	var sequence := logic.new_sequence()
	assert_eq(sequence.size(), DigitSpanLogic.START_LENGTH)
	var expected := logic.expected()
	assert_eq(expected[0], sequence[sequence.size() - 1])
	assert_false(logic.check(sequence.duplicate()) if sequence != expected else false)
	var forward := DigitSpanLogic.new(false, _rng(8))
	var seq2 := forward.new_sequence()
	assert_true(forward.check(seq2.duplicate()))
	assert_eq(forward.tracker.length, DigitSpanLogic.START_LENGTH + 1)


func test_matrix_rounds_adapt_level() -> void:
	var logic := MatrixLogic.new(4, 3, _rng(5))
	var pattern := logic.new_round()
	assert_eq(pattern.size(), MatrixLogic.START_LEVEL)
	var unique := pattern.duplicate()
	unique.sort()
	for i in range(1, unique.size()):
		assert_ne(unique[i], unique[i - 1])
	for cell in pattern:
		assert_true(logic.select(cell))
	assert_false(logic.select(pattern[0]))
	assert_true(logic.is_round_complete())
	assert_true(logic.finish_round())
	assert_eq(logic.level, MatrixLogic.START_LEVEL + 1)
	assert_eq(logic.max_level, MatrixLogic.START_LEVEL)
	logic.new_round()
	for i in logic.cell_count():
		if not logic.pattern.has(i):
			logic.select(i)
			break
	for cell in logic.pattern:
		logic.select(cell)
	assert_true(logic.is_round_complete())
	assert_false(logic.finish_round())
	assert_eq(logic.level, MatrixLogic.START_LEVEL)
	assert_false(logic.is_done())
	logic.new_round()
	for cell in logic.pattern:
		logic.select(cell)
	logic.finish_round()
	assert_true(logic.is_done())
	assert_eq(logic.build_result(&"memory_matrix", {}).error_count, 1)


func test_simon_sequence_and_failure() -> void:
	var logic := SimonLogic.new(_rng(6))
	assert_eq(logic.extend().size(), 1)
	assert_true(logic.press(logic.sequence[0]))
	assert_true(logic.round_complete())
	assert_eq(logic.extend().size(), 2)
	assert_true(logic.press(logic.sequence[0]))
	assert_false(logic.press((logic.sequence[1] + 1) % SimonLogic.PAD_COUNT))
	assert_true(logic.failed)
	assert_true(logic.is_done())
	assert_eq(logic.best_length(), 1)
