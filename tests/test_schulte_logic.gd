extends TestCase


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _config(size: int, extra: Dictionary = {}) -> SchulteConfig:
	var data := {"grid_size": size}
	data.merge(extra)
	return SchulteConfig.from_dict(data)


func _logic(size: int, seed_value: int, extra: Dictionary = {}) -> SchulteLogic:
	return SchulteLogic.new(_config(size, extra), _rng(seed_value))


## Cell index holding the current target.
func _target_cell(logic: SchulteLogic) -> int:
	for i in logic.cell_values.size():
		if logic.cell_values[i] == logic.target_values[logic.next_index] and logic.cell_colors[i] == logic.target_colors[logic.next_index]:
			return i
	return -1


func _solve(logic: SchulteLogic, step_ms: int) -> void:
	var step := 1
	while not logic.finished:
		logic.register_click(_target_cell(logic), step * step_ms)
		step += 1


func test_cells_are_a_permutation_for_every_size() -> void:
	for size in range(SchulteConfig.MIN_GRID_SIZE, SchulteConfig.MAX_GRID_SIZE + 1):
		var logic := _logic(size, 1)
		var sorted := logic.cell_values.duplicate()
		sorted.sort()
		assert_eq(sorted.size(), size * size, "size %d" % size)
		for i in sorted.size():
			assert_eq(sorted[i], i + 1, "size %d" % size)


func test_same_seed_gives_same_layout_and_seeds_differ() -> void:
	assert_eq(_logic(5, 42).cell_values, _logic(5, 42).cell_values)
	assert_ne(_logic(5, 42).cell_values, _logic(5, 43).cell_values)


func test_correct_sequence_completes() -> void:
	var logic := _logic(3, 7)
	for target in range(1, 9):
		assert_eq(logic.register_click(_target_cell(logic), target * 100), SchulteLogic.ClickOutcome.CORRECT)
		assert_eq(logic.next_target_value(), target + 1)
	assert_eq(logic.register_click(_target_cell(logic), 900), SchulteLogic.ClickOutcome.COMPLETED)
	assert_true(logic.finished)
	assert_eq(logic.total_time_ms(), 900)
	assert_eq(logic.error_count, 0)


func test_wrong_click_counts_error_and_keeps_target() -> void:
	var logic := _logic(3, 7)
	var wrong_index := logic.cell_values.find(5)
	assert_eq(logic.register_click(wrong_index, 100), SchulteLogic.ClickOutcome.WRONG)
	assert_eq(logic.register_click(wrong_index, 200), SchulteLogic.ClickOutcome.WRONG)
	assert_eq(logic.next_target_value(), 1)
	assert_eq(logic.error_count, 2)
	assert_eq(logic.errors_by_target[0], 2)
	assert_eq(logic.found_at_ms.size(), 0)


func test_clicks_after_completion_and_out_of_range_are_ignored() -> void:
	var logic := _logic(3, 7)
	assert_eq(logic.register_click(-1, 10), SchulteLogic.ClickOutcome.IGNORED)
	assert_eq(logic.register_click(9, 10), SchulteLogic.ClickOutcome.IGNORED)
	_solve(logic, 100)
	assert_eq(logic.register_click(0, 5000), SchulteLogic.ClickOutcome.IGNORED)
	assert_eq(logic.error_count, 0)
	assert_eq(logic.total_time_ms(), 900)


func test_search_times_slowest_and_average() -> void:
	var logic := _logic(3, 7)
	var stamps: Array[int] = [100, 300, 350, 1350, 1400, 1500, 1600, 1700, 1800]
	for target in range(1, 10):
		logic.register_click(_target_cell(logic), stamps[target - 1])
	assert_eq(logic.search_times_ms(), [100, 200, 50, 1000, 50, 100, 100, 100, 100] as Array[int])
	assert_eq(logic.slowest_target_text(), "4")
	assert_eq(logic.average_ms_per_target(), 200.0)


func test_build_result_carries_times_and_config() -> void:
	var logic := _logic(3, 7)
	logic.register_click(logic.cell_values.find(2), 50)
	_solve(logic, 100)
	var result := logic.build_result(&"schulte_table", {"grid_size": 3})
	assert_eq(result.drill_id, &"schulte_table")
	assert_eq(result.total_ms, 900)
	assert_eq(result.error_count, 1)
	assert_eq(result.config, {"grid_size": 3})
	assert_eq(result.summary_rows.size(), 5)
	assert_eq(result.summary_rows[0][0], "RESULT_TIME")
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
	assert_true(SchulteConfig.from_dict({}).show_errors)
	assert_false(SchulteConfig.from_dict({}).highlight_correct)
	assert_false(SchulteConfig.from_dict({"show_errors": false}).show_errors)
	assert_false(SchulteConfig.from_dict({}).show_timer)
	assert_true(SchulteConfig.from_dict({"show_timer": true}).show_timer)
	assert_eq(SchulteConfig.from_dict({"grid_size": 7, "symbols": "letters"}).grid_size, SchulteConfig.MAX_LETTER_GRID_SIZE)
	var rb := SchulteConfig.from_dict({"grid_size": 3, "symbols": "letters", "red_black": true})
	assert_eq(rb.grid_size, SchulteConfig.RED_BLACK_GRID_SIZE)
	assert_eq(rb.symbols, SchulteConfig.SYMBOLS_NUMBERS)


func test_letters_and_reverse_order() -> void:
	var letters := _logic(3, 2, {"symbols": "letters"})
	assert_eq(letters.symbol_text(1), "A")
	assert_eq(letters.symbol_text(9), "I")
	assert_eq(letters.next_target_text(), "A")
	var reverse := _logic(3, 2, {"reverse": true})
	assert_eq(reverse.next_target_value(), 9)
	assert_eq(reverse.register_click(reverse.cell_values.find(9), 100), SchulteLogic.ClickOutcome.CORRECT)
	assert_eq(reverse.next_target_value(), 8)


func test_shuffle_after_click_keeps_found_symbols_marked() -> void:
	var logic := _logic(4, 3, {"shuffle_after_click": true})
	var before := logic.cell_values.duplicate()
	logic.register_click(_target_cell(logic), 100)
	assert_ne(logic.cell_values, before)
	assert_true(logic.is_found(logic.cell_values.find(1)))
	assert_false(logic.is_found(logic.cell_values.find(2)))
	_solve(logic, 100)
	assert_true(logic.finished)


func test_red_black_targets_alternate() -> void:
	var logic := _logic(5, 4, {"red_black": true})
	assert_eq(logic.grid_size, 7)
	assert_eq(logic.target_count(), 49)
	assert_eq(logic.target_values.slice(0, 5), [1, 24, 2, 23, 3] as Array[int])
	assert_eq(logic.target_colors.slice(0, 4), [0, 1, 0, 1] as Array[int])
	assert_eq(logic.target_values[48], 25)
	assert_eq(logic.target_colors[48], 0)
	var reds := 0
	for c in logic.cell_colors:
		if c == SchulteLogic.COLOR_RED:
			reds += 1
	assert_eq(reds, 24)
	# Clicking black 24 while red 24 is wanted is an error.
	logic.register_click(_target_cell(logic), 100)
	assert_true(logic.next_target_is_red())
	var black_24 := -1
	for i in 49:
		if logic.cell_values[i] == 24 and logic.cell_colors[i] == SchulteLogic.COLOR_PRIMARY:
			black_24 = i
	assert_eq(logic.register_click(black_24, 200), SchulteLogic.ClickOutcome.WRONG)
	assert_eq(logic.register_click(_target_cell(logic), 300), SchulteLogic.ClickOutcome.CORRECT)
	_solve(logic, 100)
	assert_true(logic.finished)
	assert_eq(logic.found_at_ms.size(), 49)


func test_schulte_test_indices() -> void:
	var times: Array[int] = [40000, 38000, 36000, 42000, 44000]
	var indices := SchulteLogic.test_indices(times)
	assert_eq(indices["er_ms"], 40000.0)
	assert_eq(indices["wu"], 1.0)
	assert_eq(indices["ps"], 1.05)
	var result := SchulteLogic.build_test_result(&"schulte_table", {}, times, 3)
	assert_eq(result.total_ms, 40000)
	assert_eq(result.error_count, 3)
	assert_eq(result.summary_rows.size(), 9)
	assert_eq(result.summary_rows[0][0], "SCHULTE_TEST_T1")
