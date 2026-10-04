extends TestCase


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_staircase_moves_and_tracks_threshold() -> void:
	var stairs := Staircase.new(100.0, 10.0, 200.0, 10.0, 20.0)
	assert_false(stairs.has_threshold())
	stairs.record(true)
	assert_eq(stairs.value, 90.0)
	assert_eq(stairs.best, 100.0)
	stairs.record(true)
	assert_eq(stairs.best, 90.0)
	stairs.record(false)
	assert_eq(stairs.value, 100.0)
	assert_eq(stairs.reversals, 1)
	for i in 30:
		stairs.record(false)
	assert_eq(stairs.value, 200.0)
	for i in 30:
		stairs.record(true)
	assert_eq(stairs.value, 10.0)
	assert_eq(stairs.best, 10.0)


func test_mirrored_choice_wants_opposite_side() -> void:
	var logic := ChoiceLogic.new(6, _rng(1), true)
	var cued := logic.current_side()
	assert_eq(logic.correct_side(), 1 - cued)
	assert_false(logic.record_response(cued, 300))
	assert_true(logic.record_response(logic.correct_side(), 300))


func test_simon_effect_congruency() -> void:
	var logic := SimonEffectLogic.new(20, _rng(2))
	var congruent := 0
	while not logic.is_done():
		if logic.current_is_congruent():
			congruent += 1
		logic.record_response(logic.directions[logic.current], 500 if logic.current_is_congruent() else 560)
	assert_eq(congruent, 10)
	assert_eq(logic.simon_effect_ms(), 60.0)
	assert_eq(logic.accuracy(), 1.0)


func test_posner_validity_ratio() -> void:
	var logic := PosnerLogic.new(20, _rng(3))
	var valid := 0
	while not logic.is_done():
		if logic.current_is_valid():
			valid += 1
		logic.record_response(logic.target_side[logic.current], 300 if logic.current_is_valid() else 350)
	assert_eq(valid, 16)
	assert_eq(logic.validity_effect_ms(), 50.0)


func test_peripheral_detection_and_centre_count() -> void:
	var logic := PeripheralLogic.new(10, _rng(4))
	assert_eq(logic.offsets.size(), 10)
	for offset in logic.offsets:
		var r := offset.length()
		assert_true(r >= PeripheralLogic.MIN_RADIUS - 0.001 and r <= PeripheralLogic.MAX_RADIUS + 0.001)
	assert_true(logic.respond(300))
	assert_false(logic.respond(350))
	logic.close_window()
	logic.close_window()
	assert_eq(logic.misses, 1)
	assert_eq(logic.detect_stats.count(), 1)
	assert_eq(logic.report_centre_changes(logic.centre_change_count), true)
	assert_ne(logic.next_centre_digit(5), 5)


func test_masking_options_and_staircase() -> void:
	var logic := MaskingLogic.new(5, _rng(5))
	logic.new_trial()
	assert_eq(logic.options.size(), 4)
	assert_true(logic.options.has(logic.target))
	var unique := logic.options.duplicate()
	unique.sort()
	for i in range(1, unique.size()):
		assert_ne(unique[i], unique[i - 1])
	assert_eq(logic.mask_text().length(), 3)
	assert_true(logic.answer(logic.target))
	assert_eq(logic.exposure_ms(), MaskingLogic.START_MS - MaskingLogic.STEP_DOWN_MS)
	logic.new_trial()
	var wrong := logic.options[0] if logic.options[0] != logic.target else logic.options[1]
	assert_false(logic.answer(wrong))
	assert_eq(logic.exposure_ms(), MaskingLogic.START_MS - MaskingLogic.STEP_DOWN_MS + MaskingLogic.STEP_UP_MS)


func test_toj_threshold() -> void:
	var logic := TojLogic.new(3, _rng(6))
	logic.new_trial()
	assert_true(logic.answer(logic.first_side))
	logic.new_trial()
	assert_false(logic.answer(1 - logic.first_side))
	logic.new_trial()
	logic.answer(logic.first_side)
	assert_true(logic.is_done())
	# The threshold is the smallest gap answered correctly: the starting value.
	assert_eq(logic.build_result(&"temporal_order", {}).total_ms, roundi(TojLogic.START_MS))


func test_go_no_go_adaptive_duration() -> void:
	var logic := GoNoGoLogic.new(10, _rng(7), true)
	var start := logic.stimulus_ms()
	assert_eq(start, float(GoNoGoLogic.STIMULUS_MS))
	if logic.current_is_go():
		logic.record_response(300)
	else:
		logic.record_no_response()
	assert_eq(logic.stimulus_ms(), start - GoNoGoLogic.ADAPTIVE_STEP_DOWN_MS)
	var fixed := GoNoGoLogic.new(10, _rng(7), false)
	fixed.record_no_response()
	assert_eq(fixed.stimulus_ms(), float(GoNoGoLogic.STIMULUS_MS))
