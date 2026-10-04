extends TestCase


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_ttc_trajectory_lands_in_view() -> void:
	var logic := TtcLogic.new(5, _rng(1))
	while not logic.is_done():
		var impact := logic.impact_point()
		assert_true(absf(impact.z - TtcLogic.IMPACT_Z) < 0.01)
		assert_true(absf(impact.x) <= 1.0 and absf(impact.y) <= 0.55)
		# The arc must stay inside the view: apex below the 30-degree half angle at its depth.
		var apex := logic.position_at(logic.flight_seconds() * 0.5)
		assert_true(apex.y < -apex.z * tan(deg_to_rad(30.0)))
		assert_true(logic.is_visible_at(0.1))
		assert_false(logic.is_visible_at(logic.flight_seconds() * 0.9))
		var error := logic.record(logic.flight_seconds() + 0.05, 0.1)
		assert_eq(error, 50)
	assert_eq(logic.mean_abs_time_error_ms(), 50.0)
	assert_true(absf(logic.mean_position_error() - 0.1) < 0.0001)


func test_brock_cues_and_letters() -> void:
	var logic := BrockLogic.new(10, _rng(2))
	for i in range(1, 10):
		assert_ne(logic.cue[i], logic.cue[i - 1])
	logic.new_trial()
	assert_eq(logic.options.size(), 4)
	assert_true(logic.options.has(logic.target))
	assert_eq(logic.letter_on(logic.current_bead()), logic.target)
	for bead in 3:
		if bead != logic.current_bead():
			assert_ne(logic.letter_on(bead), logic.target)
	assert_true(logic.answer(logic.target, 600))
	assert_false(logic.answer("?", 600))
	assert_eq(logic.wrong_count, 1)


func test_rotation_3d_mirror_differs() -> void:
	var logic := Rotation3DLogic.new(6, _rng(3))
	var mirrored := 0
	while not logic.is_done():
		var reference := logic.reference_cubes()
		var probe := logic.probe_cubes()
		assert_eq(probe.size(), reference.size())
		if logic.mirrored[logic.current]:
			mirrored += 1
			assert_ne(probe, reference)
		else:
			assert_eq(probe, reference)
		assert_true(logic.answer(not logic.mirrored[logic.current], 900))
	assert_eq(mirrored, 3)


func test_looming_geometry() -> void:
	var logic := LoomingLogic.new(4, _rng(4))
	assert_eq(logic.radius_at(0.0), LoomingLogic.START_RADIUS)
	assert_true(absf(logic.radius_at(LoomingLogic.GROW_SECONDS) - LoomingLogic.END_RADIUS) < 0.0001)
	var offset := Vector2(0.12, 0.0)
	assert_false(LoomingLogic.misses(offset, Vector2.ZERO, LoomingLogic.END_RADIUS))
	assert_true(LoomingLogic.misses(offset, Vector2(-0.3, 0.0), LoomingLogic.END_RADIUS))
	logic.record(true, 300)
	logic.record(false, -1)
	assert_eq(logic.evaded, 1)
	assert_eq(logic.reaction_stats.count(), 1)
