extends TestCase


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _solve(logic: SchulteLogic, step_ms: int) -> void:
	for target in range(1, logic.total_count() + 1):
		logic.register_click(logic.cells.find(target), target * step_ms)


func test_cells_are_a_permutation_for_every_size() -> void:
	for size in range(SchulteConfig.MIN_GRID_SIZE, SchulteConfig.MAX_GRID_SIZE + 1):
		var logic := SchulteLogic.new(size, _rng(1))
		var sorted := logic.cells.duplicate()
		sorted.sort()
		assert_eq(sorted.size(), size * size, "size %d" % size)
		for i in sorted.size():
			assert_eq(sorted[i], i + 1, "size %d" % size)


func test_same_seed_gives_same_layout_and_seeds_differ() -> void:
	assert_eq(SchulteLogic.new(5, _rng(42)).cells, SchulteLogic.new(5, _rng(42)).cells)
	assert_ne(SchulteLogic.new(5, _rng(42)).cells, SchulteLogic.new(5, _rng(43)).cells)


func test_correct_sequence_completes() -> void:
	var logic := SchulteLogic.new(3, _rng(7))
	for target in range(1, 9):
		assert_eq(logic.register_click(logic.cells.find(target), target * 100), SchulteLogic.ClickOutcome.CORRECT)
		assert_eq(logic.next_target, target + 1)
	assert_eq(logic.register_click(logic.cells.find(9), 900), SchulteLogic.ClickOutcome.COMPLETED)
	assert_true(logic.finished)
	assert_eq(logic.total_time_ms(), 900)
	assert_eq(logic.error_count, 0)


func test_wrong_click_counts_error_and_keeps_target() -> void:
	var logic := SchulteLogic.new(3, _rng(7))
	var wrong_index := logic.cells.find(5)
	assert_eq(logic.register_click(wrong_index, 100), SchulteLogic.ClickOutcome.WRONG)
	assert_eq(logic.register_click(wrong_index, 200), SchulteLogic.ClickOutcome.WRONG)
	assert_eq(logic.next_target, 1)
	assert_eq(logic.error_count, 2)
	assert_eq(logic.errors_by_target[1], 2)
	assert_eq(logic.found_at_ms.size(), 0)


func test_clicks_after_completion_and_out_of_range_are_ignored() -> void:
	var logic := SchulteLogic.new(3, _rng(7))
	assert_eq(logic.register_click(-1, 10), SchulteLogic.ClickOutcome.IGNORED)
	assert_eq(logic.register_click(9, 10), SchulteLogic.ClickOutcome.IGNORED)
	_solve(logic, 100)
	assert_eq(logic.register_click(0, 5000), SchulteLogic.ClickOutcome.IGNORED)
	assert_eq(logic.error_count, 0)
	assert_eq(logic.total_time_ms(), 900)


func test_search_times_slowest_and_average() -> void:
	var logic := SchulteLogic.new(3, _rng(7))
	var stamps: Array[int] = [100, 300, 350, 1350, 1400, 1500, 1600, 1700, 1800]
	for target in range(1, 10):
		logic.register_click(logic.cells.find(target), stamps[target - 1])
	assert_eq(logic.search_times_ms(), [100, 200, 50, 1000, 50, 100, 100, 100, 100] as Array[int])
	assert_eq(logic.slowest_target(), 4)
	assert_eq(logic.average_ms_per_target(), 200.0)


func test_build_result_carries_times_and_config() -> void:
	var logic := SchulteLogic.new(3, _rng(7))
	logic.register_click(logic.cells.find(2), 50)
	_solve(logic, 100)
	var result := logic.build_result(&"schulte_table", {"grid_size": 3})
	assert_eq(result.drill_id, &"schulte_table")
	assert_eq(result.total_ms, 900)
	assert_eq(result.error_count, 1)
	assert_eq(result.config, {"grid_size": 3})
	assert_eq(result.summary_rows.size(), 3)
	assert_eq(result.details["found_at_ms"], [100, 200, 300, 400, 500, 600, 700, 800, 900] as Array[int])
	assert_true(result.finished_at_unix > 0)


func test_config_round_trip_and_clamping() -> void:
	var config := SchulteConfig.from_dict({"grid_size": 99, "countdown": false, "dim_found": true})
	assert_eq(config.grid_size, SchulteConfig.MAX_GRID_SIZE)
	assert_false(config.countdown)
	assert_true(config.dim_found)
	assert_false(config.fixation_dot)
	assert_eq(SchulteConfig.from_dict({"grid_size": 1.0}).grid_size, SchulteConfig.MIN_GRID_SIZE)
	assert_eq(SchulteConfig.from_dict(config.to_dict()).to_dict(), config.to_dict())
	assert_eq(SchulteConfig.from_dict({}).grid_size, SchulteConfig.DEFAULT_GRID_SIZE)
