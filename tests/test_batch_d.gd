extends TestCase


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_rotation_transforms() -> void:
	var cells: Array[Vector2i] = []
	cells.assign(RotationLogic.SHAPES[0])
	var base := RotationLogic.normalized(cells)
	assert_eq(RotationLogic.transform(cells, 4, false), base)
	assert_ne(RotationLogic.transform(cells, 1, false), base)
	# A mirrored pentomino never equals a rotation of the original (all shapes are chiral).
	for shape in RotationLogic.SHAPES:
		var c: Array[Vector2i] = []
		c.assign(shape)
		for turns in 4:
			assert_ne(RotationLogic.transform(c, turns, true), RotationLogic.transform(c, 0, false))
	var logic := RotationLogic.new(10, _rng(1))
	var mirrored := 0
	while not logic.is_done():
		if logic.mirrored[logic.current]:
			mirrored += 1
		assert_true(logic.answer(not logic.mirrored[logic.current], 700))
	assert_eq(mirrored, 5)
	assert_eq(logic.accuracy(), 1.0)


func test_spotlight_targets() -> void:
	var logic := SpotlightLogic.new(64, 5, _rng(2))
	assert_eq(logic.targets.size(), 5)
	var ts := 0
	for i in 64:
		if logic.letter_at(i) == SpotlightLogic.TARGET:
			ts += 1
	assert_eq(ts, 5)
	var distractor := 0
	while logic.targets.has(distractor):
		distractor += 1
	assert_false(logic.click(distractor, 100))
	assert_true(logic.click(logic.targets[0], 200))
	assert_false(logic.click(logic.targets[0], 300))
	assert_eq(logic.wrong_count, 2)
	for t in logic.targets:
		logic.click(t, 1000)
	assert_true(logic.is_done())
	assert_eq(logic.total_time_ms(), 1000)


func test_contrast_staircase() -> void:
	var logic := ContrastLogic.new(3, _rng(3))
	logic.new_trial()
	assert_true(logic.answer(logic.orientation_index))
	assert_true(absf(logic.contrast() - (ContrastLogic.START - ContrastLogic.STEP_DOWN)) < 0.0001)
	logic.new_trial()
	assert_false(logic.answer((logic.orientation_index + 1) % 4))
	assert_true(absf(logic.contrast() - (ContrastLogic.START - ContrastLogic.STEP_DOWN + ContrastLogic.STEP_UP)) < 0.0001)
	assert_true(absf(logic.orientation_radians() - deg_to_rad(ContrastLogic.ORIENTATIONS_DEG[logic.orientation_index])) < 0.0001)


func test_okn_detection() -> void:
	var logic := OknLogic.new(3, _rng(4))
	assert_ne(logic.next_digit(7), 7)
	assert_true(logic.respond(400))
	assert_false(logic.respond(450))
	logic.close_window()
	logic.respond_outside_window()
	logic.close_window()
	logic.close_window()
	assert_true(logic.is_done())
	assert_eq(logic.misses, 2)
	assert_eq(logic.false_alarms, 1)
	assert_eq(logic.build_result(&"okn_stripes", {}).error_count, 3)
