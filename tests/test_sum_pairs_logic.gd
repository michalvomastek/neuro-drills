extends TestCase


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _blank(logic: SumPairsLogic) -> void:
	logic.grid.fill(0)
	logic.selection.clear()
	logic.target = 10


func test_board_density_and_move_exists() -> void:
	for size: int in [4, 5, 6]:
		var logic := SumPairsLogic.new(size, false, _rng(size))
		var filled := 0
		for v in logic.grid:
			if v != 0:
				filled += 1
				assert_true(v >= 1 and v <= 9)
		assert_eq(filled, logic.number_count())
		assert_true(logic.valid_pairs().size() >= SumPairsLogic.MIN_PAIRS, "size %d starts with %d pairs" % [size, SumPairsLogic.MIN_PAIRS])
	# A forced pair on a board where nothing sees anything.
	var tiny := SumPairsLogic.new(4, false, _rng(11))
	tiny.grid.fill(0)
	tiny.grid[0] = 3
	tiny.grid[15] = 3
	tiny._ensure_move()
	assert_true(tiny.has_move(), "the forced pair makes a move")


func test_line_of_sight() -> void:
	var logic := SumPairsLogic.new(4, false, _rng(1))
	_blank(logic)
	logic.grid[0] = 3
	logic.grid[3] = 7
	logic.grid[15] = 7
	logic.grid[12] = 1
	assert_true(logic.line_clear(0, 3), "row clear")
	assert_false(logic.line_clear(0, 15), "diagonal is not a line")
	assert_true(logic.line_clear(0, 12), "column clear")
	assert_false(logic.line_clear(3, 12), "anti-diagonal is not a line")
	assert_eq(logic.cells_between(0, 3), [1, 2] as Array[int])
	assert_eq(logic.cells_between(12, 0), [4, 8] as Array[int])
	assert_eq(logic.cells_between(0, 5), [] as Array[int], "no shared row or column")
	logic.grid[1] = 5
	assert_false(logic.line_clear(0, 3), "row blocked by 1")
	assert_false(logic.line_clear(0, 6), "knight move is no line")
	assert_true(logic.line_clear(1, 13), "column through empty cells")
	assert_true(logic.line_clear(12, 0) == logic.line_clear(0, 12), "symmetric")


func test_pair_completes_and_refills() -> void:
	var logic := SumPairsLogic.new(4, false, _rng(2))
	_blank(logic)
	logic.grid[0] = 4
	logic.grid[3] = 6
	logic.grid[5] = 2
	assert_eq(logic.tap(0, 500), SumPairsLogic.Outcome.SELECTED)
	assert_true(logic.is_selected(0))
	assert_eq(logic.tap(0, 600), SumPairsLogic.Outcome.DESELECTED)
	assert_eq(logic.tap(0, 700), SumPairsLogic.Outcome.SELECTED)
	assert_eq(logic.tap(3, 1200), SumPairsLogic.Outcome.COMPLETED)
	assert_eq(logic.completed, 1)
	assert_eq(logic.cleared_count, 2)
	assert_eq(logic.times_ms, [1200] as Array[int])
	assert_eq(logic.distances, [3] as Array[int])
	var filled := 0
	for v in logic.grid:
		if v != 0:
			filled += 1
	assert_eq(filled, 3, "two numbers came back somewhere")
	assert_eq(logic.value_at(0), 0, "not into the cleared cells")
	assert_eq(logic.value_at(3), 0, "not into the cleared cells")
	assert_true(logic.has_move())
	assert_true(logic.selection.is_empty())


func test_wrong_sum_and_blocked_count_as_invalid() -> void:
	var logic := SumPairsLogic.new(4, false, _rng(3))
	_blank(logic)
	logic.grid[0] = 4
	logic.grid[1] = 5
	logic.grid[2] = 6
	assert_eq(logic.tap(0, 100), SumPairsLogic.Outcome.SELECTED)
	assert_eq(logic.tap(2, 200), SumPairsLogic.Outcome.BLOCKED)
	assert_eq(logic.invalid_count, 1)
	assert_true(logic.selection.is_empty())
	assert_eq(logic.tap(0, 300), SumPairsLogic.Outcome.SELECTED)
	assert_eq(logic.tap(1, 400), SumPairsLogic.Outcome.WRONG_SUM)
	assert_eq(logic.invalid_count, 2)
	assert_eq(logic.tap(7, 500), SumPairsLogic.Outcome.IGNORED)
	assert_eq(logic.completed, 0)


func test_chains_sum_up_to_target() -> void:
	var logic := SumPairsLogic.new(4, true, _rng(4))
	_blank(logic)
	logic.grid[0] = 2
	logic.grid[2] = 3
	logic.grid[10] = 5
	logic.grid[3] = 9
	assert_eq(logic.tap(0, 100), SumPairsLogic.Outcome.SELECTED)
	assert_eq(logic.tap(2, 200), SumPairsLogic.Outcome.SELECTED)
	assert_eq(logic.selection_sum(), 5)
	assert_eq(logic.tap(3, 250), SumPairsLogic.Outcome.WRONG_SUM, "over the target")
	assert_eq(logic.tap(0, 300), SumPairsLogic.Outcome.SELECTED)
	assert_eq(logic.tap(2, 400), SumPairsLogic.Outcome.SELECTED)
	assert_eq(logic.tap(10, 500), SumPairsLogic.Outcome.COMPLETED, "2 -> 3 along the row, 3 -> 5 down the column")
	assert_eq(logic.chain_count, 1)
	assert_eq(logic.cleared_count, 3)
	assert_eq(logic.distances, [2, 2] as Array[int])
	# Without chains the same second tap is a wrong sum.
	var plain := SumPairsLogic.new(4, false, _rng(4))
	_blank(plain)
	plain.grid[0] = 2
	plain.grid[2] = 3
	plain.grid[10] = 5
	plain.tap(0, 100)
	assert_eq(plain.tap(2, 200), SumPairsLogic.Outcome.WRONG_SUM)


func test_target_changes_and_always_has_pairs() -> void:
	var logic := SumPairsLogic.new(5, false, _rng(5))
	var targets: Array[int] = []
	for round in 30:
		assert_true(logic.target >= SumPairsLogic.TARGET_MIN and logic.target <= SumPairsLogic.TARGET_MAX)
		if not targets.has(logic.target):
			targets.append(logic.target)
		var pairs := logic.valid_pairs()
		assert_false(pairs.is_empty(), "round %d has a pair for %d" % [round, logic.target])
		var pair: Vector2i = pairs[0]
		assert_eq(logic.tap(pair.x, round * 1000), SumPairsLogic.Outcome.SELECTED)
		assert_eq(logic.tap(pair.y, round * 1000 + 500), SumPairsLogic.Outcome.COMPLETED)
		assert_true(logic.valid_pairs().size() >= SumPairsLogic.MIN_PAIRS, "round %d keeps %d pairs" % [round, SumPairsLogic.MIN_PAIRS])
	assert_eq(logic.completed, 30)
	assert_true(targets.size() >= 3, "the target moved around: %s" % [targets])


## Many random boards and moves: the two-pair floor holds on every one.
func test_two_pairs_floor_holds_on_random_boards() -> void:
	for seed_value in 40:
		for size: int in [4, 5, 6]:
			var logic := SumPairsLogic.new(size, false, _rng(seed_value))
			for round in 15:
				var pairs := logic.valid_pairs()
				assert_true(pairs.size() >= SumPairsLogic.MIN_PAIRS, "seed %d size %d round %d: %d pairs" % [seed_value, size, round, pairs.size()])
				var pair: Vector2i = pairs[seed_value % pairs.size()]
				logic.tap(pair.x, round * 100)
				assert_eq(logic.tap(pair.y, round * 100 + 50), SumPairsLogic.Outcome.COMPLETED)


func test_build_result_metrics() -> void:
	var logic := SumPairsLogic.new(4, false, _rng(6))
	_blank(logic)
	logic.grid[0] = 1
	logic.grid[1] = 9
	logic.grid[8] = 5
	logic.tap(0, 1000)
	logic.tap(1, 2000)
	logic.tap(8, 2500)
	logic.tap(0, 2600)
	logic.selection.clear()
	logic.invalid_count = 1
	var result := logic.build_result(&"sum_pairs", {"size": 4}, 10000)
	assert_eq(result.metrics["ms_per_pair"], 10000.0)
	assert_eq(result.metrics["invalid_rate"], 0.5)
	assert_eq(result.metrics["mean_distance"], 1.0)
	assert_eq(result.metrics["pairs"], 1.0)
	assert_eq(result.error_count, 1)
	assert_eq(result.summary_rows.size(), 4)
	var empty := SumPairsLogic.new(4, false, _rng(7))
	var none := empty.build_result(&"sum_pairs", {}, 30000)
	assert_eq(none.metrics["ms_per_pair"], 30000.0)
	assert_eq(none.metrics["invalid_rate"], 0.0)
