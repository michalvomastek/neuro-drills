extends TestCase


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_reaction_stats_summaries() -> void:
	var stats := ReactionStats.new()
	assert_eq(stats.median(), 0.0)
	assert_eq(stats.best(), 0)
	for t: int in [300, 250, 400, 350]:
		stats.add(t)
	assert_eq(stats.mean(), 325.0)
	assert_eq(stats.median(), 325.0)
	assert_eq(stats.best(), 250)
	stats.add(1000)
	assert_eq(stats.median(), 350.0)
	assert_true(stats.std_dev() > 0.0)


func test_reaction_logic_counts_trials_and_premature() -> void:
	var logic := ReactionLogic.new(3, _rng(1))
	for i in 20:
		var delay := logic.next_delay_ms()
		assert_true(delay >= ReactionLogic.MIN_DELAY_MS and delay <= ReactionLogic.MAX_DELAY_MS)
	logic.record_premature()
	logic.record_reaction(300)
	logic.record_reaction(280)
	assert_false(logic.is_done())
	logic.record_reaction(320)
	assert_true(logic.is_done())
	var result := logic.build_result(&"reaction_time", {"trials": 3})
	assert_eq(result.total_ms, 300)
	assert_eq(result.error_count, 1)
	assert_eq(result.summary_rows.size(), 4)


func test_choice_logic_scores_sides() -> void:
	var logic := ChoiceLogic.new(10, _rng(5))
	assert_eq(logic.sides.size(), 10)
	var first := logic.current_side()
	assert_true(logic.record_response(first, 400))
	assert_false(logic.record_response(1 - logic.current_side(), 400))
	assert_eq(logic.wrong_count, 1)
	assert_eq(logic.current, 2)
	while not logic.is_done():
		logic.record_response(logic.current_side(), 350)
	assert_eq(logic.accuracy(), 0.9)
	assert_eq(logic.stats.count(), 9)


func test_go_no_go_mix_and_scoring() -> void:
	var logic := GoNoGoLogic.new(20, _rng(9))
	var go_count := 0
	for go in logic.is_go:
		if go:
			go_count += 1
	assert_eq(go_count, 15)
	var hits := 0
	var false_alarms := 0
	var misses := 0
	var rejections := 0
	for i in 20:
		# Respond to every even trial, withhold on odd ones.
		var go := logic.current_is_go()
		if i % 2 == 0:
			var correct := logic.record_response(300)
			assert_eq(correct, go)
			if go:
				hits += 1
			else:
				false_alarms += 1
		else:
			var correct := logic.record_no_response()
			assert_eq(correct, not go)
			if go:
				misses += 1
			else:
				rejections += 1
	assert_true(logic.is_done())
	assert_eq(logic.hit_stats.count(), hits)
	assert_eq(logic.false_alarms, false_alarms)
	assert_eq(logic.misses, misses)
	assert_eq(logic.correct_rejections, rejections)
	assert_eq(logic.build_result(&"go_no_go", {}).error_count, misses + false_alarms)


func test_stroop_congruency_split() -> void:
	var logic := StroopLogic.new(24, _rng(3))
	var congruent := 0
	for i in 24:
		if logic.word_index[i] == logic.ink_index[i]:
			congruent += 1
		assert_true(logic.ink_index[i] >= 0 and logic.ink_index[i] < StroopLogic.COLOR_COUNT)
	assert_eq(congruent, 12)
	while not logic.is_done():
		var rt := 500 if logic.current_is_congruent() else 700
		logic.record_response(logic.ink_index[logic.current], rt)
	assert_eq(logic.congruent_stats.count(), 12)
	assert_eq(logic.incongruent_stats.count(), 12)
	assert_eq(logic.interference_ms(), 200.0)
	assert_eq(logic.accuracy(), 1.0)


func test_flanker_stimulus_strings() -> void:
	var logic := FlankerLogic.new(12, _rng(4))
	var congruent := 0
	while not logic.is_done():
		var stimulus := logic.current_stimulus()
		assert_eq(stimulus.length(), 5)
		var middle := stimulus[2]
		assert_eq(middle, "<" if logic.target[logic.current] == 0 else ">")
		if logic.congruent[logic.current]:
			congruent += 1
			assert_eq(stimulus, middle.repeat(5))
		else:
			assert_ne(stimulus[0], middle)
		logic.record_response(logic.target[logic.current], 450)
	assert_eq(congruent, 6)
	assert_eq(logic.wrong_count, 0)
