extends TestCase


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_tracking_stats() -> void:
	var stats := TrackingStats.new()
	assert_eq(stats.mean(), 0.0)
	stats.add(3.0)
	stats.add(4.0)
	assert_eq(stats.mean(), 3.5)
	assert_eq(stats.max_distance, 4.0)
	assert_true(absf(stats.rms() - sqrt(12.5)) < 0.0001)


func test_mot_round_and_bounce() -> void:
	var logic := MotLogic.new(2, _rng(1))
	logic.new_round()
	assert_eq(logic.positions.size(), MotLogic.BALL_COUNT)
	assert_eq(logic.targets.size(), MotLogic.TARGET_COUNT)
	for i in 300:
		logic.step(1.0 / 60.0)
	for p in logic.positions:
		assert_true(p.x >= MotLogic.RADIUS - 0.001 and p.x <= 1.0 - MotLogic.RADIUS + 0.001)
		assert_true(p.y >= MotLogic.RADIUS - 0.001 and p.y <= 1.0 - MotLogic.RADIUS + 0.001)
	assert_eq(logic.ball_at(logic.positions[0]), 0)
	assert_eq(logic.ball_at(Vector2(-5, -5)), -1)
	for t in logic.targets:
		assert_true(logic.select(t))
	assert_true(logic.is_round_complete())
	assert_false(logic.select(99))
	assert_eq(logic.finish_round(), MotLogic.TARGET_COUNT)
	logic.new_round()
	var picks := 0
	for i in MotLogic.BALL_COUNT:
		if not logic.targets.has(i) and picks < MotLogic.TARGET_COUNT:
			logic.select(i)
			picks += 1
	assert_eq(logic.finish_round(), 0)
	assert_true(logic.is_done())
	assert_eq(logic.accuracy(), 0.5)


func test_anticipation_errors() -> void:
	var logic := AnticipationLogic.new(3, _rng(2))
	var ideal := logic.ideal_time_ms()
	assert_true(absf(logic.position_at(ideal) - AnticipationLogic.TARGET_X) < 0.002)
	assert_eq(logic.record_press(ideal - 40), -40)
	assert_eq(logic.record_press(logic.ideal_time_ms() + 100), 100)
	logic.record_press(logic.ideal_time_ms())
	assert_true(logic.is_done())
	assert_eq(logic.mean_abs_error_ms(), 140.0 / 3.0)
	assert_eq(logic.mean_signed_error_ms(), 20.0)


func test_acuity_speed_staircase() -> void:
	var logic := AcuityLogic.new(4, _rng(3))
	assert_eq(logic.speed(), AcuityLogic.START_SPEED)
	logic.new_trial()
	assert_true(logic.answer(logic.gap))
	assert_true(absf(logic.speed() - (AcuityLogic.START_SPEED + AcuityLogic.STEP_UP)) < 0.0001)
	assert_true(absf(logic.best_speed() - AcuityLogic.START_SPEED) < 0.0001)
	logic.new_trial()
	assert_false(logic.answer(((logic.gap as int) + 1) % 4 as AcuityLogic.Gap))
	assert_true(absf(logic.speed() - (AcuityLogic.START_SPEED + AcuityLogic.STEP_UP - AcuityLogic.STEP_DOWN)) < 0.0001)


func test_rhythm_drift_and_jitter() -> void:
	var logic := RhythmLogic.new(120)
	assert_eq(logic.period_ms(), 500.0)
	var t := 0
	for i in logic.total_taps():
		logic.record_tap(t)
		t += 550 if i >= RhythmLogic.CUED_BEATS - 1 else 500
	assert_true(logic.is_done())
	assert_eq(logic.continuation_intervals().size(), RhythmLogic.CONTINUATION_TAPS)
	assert_eq(logic.mean_interval_ms(), 550.0)
	assert_true(absf(logic.drift_percent() - 10.0) < 0.0001)
	assert_eq(logic.jitter_ms(), 0.0)
	logic.record_tap(99999)
	assert_eq(logic.taps_ms.size(), logic.total_taps())
