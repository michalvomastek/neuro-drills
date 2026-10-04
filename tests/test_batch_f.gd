extends TestCase


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_dual_task_phases_and_interference() -> void:
	var logic := DualTaskLogic.new(120, _rng(1))
	var t := 0
	var i := 0
	while not logic.is_done():
		logic.record_tap(t)
		var jitter := 0
		if i >= logic.load_starts_at_tap():
			jitter = 40 if i % 2 == 0 else -40
		t += 500 + jitter
		i += 1
	assert_eq(logic.taps_ms.size(), logic.total_taps())
	assert_eq(logic.baseline_jitter_ms(), 0.0)
	assert_true(logic.loaded_jitter_ms() > 30.0)
	logic.arithmetic.new_problem()
	assert_true(logic.answer_problem(logic.arithmetic.solution()))
	assert_false(logic.answer_problem(logic.arithmetic.solution() + 1))
	assert_eq(logic.problems_correct, 1)
	assert_eq(logic.problems_wrong, 1)


func test_pattern_sectors_and_distractors() -> void:
	var logic := PatternLogic.new(10, _rng(2))
	for s in logic.target_sector:
		assert_true(s >= 0 and s < PatternLogic.SECTORS)
	var target := logic.pattern_for(logic.target_sector[0])
	assert_eq(target["bars"], PatternLogic.TARGET_BARS)
	var target_colored: bool = target["target_color"]
	assert_true(target_colored)
	for i in 20:
		var other := (logic.target_sector[0] + 1) % PatternLogic.SECTORS
		var d := logic.pattern_for(other)
		var same_as_target: bool = d["bars"] == PatternLogic.TARGET_BARS and d["target_color"]
		assert_false(same_as_target)
	assert_true(logic.answer(logic.target_sector[0]))
	assert_false(logic.answer((logic.target_sector[1] + 1) % PatternLogic.SECTORS))
	assert_eq(logic.correct, 1)
	assert_true(logic.report_centre_changes(logic.centre_change_count))


func test_reading_counts() -> void:
	var logic := ReadingLogic.new(30, _rng(3))
	assert_eq(logic.letters.size(), 30)
	var occurrences := 0
	for l in logic.letters:
		if l == logic.target_letter:
			occurrences += 1
	assert_eq(occurrences, logic.target_occurrences)
	var reds := 0
	for r in logic.disc_is_red:
		if r:
			reds += 1
	assert_eq(reds, logic.red_count)
	logic.report(occurrences, reds + 1)
	assert_true(logic.letters_correct())
	assert_false(logic.reds_correct())
	assert_eq(logic.build_result(&"peripheral_reading", {}).error_count, 1)
