extends TestCase


func _result(id: StringName, metrics: Dictionary, config: Dictionary = {}) -> DrillResult:
	var r := DrillResult.new()
	r.drill_id = id
	r.metrics = metrics
	r.config = config
	return r


func test_lower_is_better_bands() -> void:
	assert_eq(Benchmarks.evaluate(_result(&"reaction_time", {"median_rt_ms": 170.0}))["level"], Benchmarks.Level.ELITE)
	assert_eq(Benchmarks.evaluate(_result(&"reaction_time", {"median_rt_ms": 240.0}))["level"], Benchmarks.Level.ADVANCED)
	var beginner := Benchmarks.evaluate(_result(&"reaction_time", {"median_rt_ms": 300.0}))
	assert_eq(beginner["level"], Benchmarks.Level.BEGINNER)
	assert_eq(beginner["next"], 270.0)


func test_higher_is_better_and_gates() -> void:
	assert_eq(Benchmarks.evaluate(_result(&"corsi_blocks", {"span": 8.0}))["level"], Benchmarks.Level.ELITE)
	assert_eq(Benchmarks.evaluate(_result(&"corsi_blocks", {"span": 5.0}))["level"], Benchmarks.Level.BEGINNER)
	# Fast but sloppy Stroop drops to beginner; fast and clean reaches elite.
	assert_eq(Benchmarks.evaluate(_result(&"stroop", {"interference_ms": 10.0, "error_rate": 0.3}))["level"], Benchmarks.Level.BEGINNER)
	assert_eq(Benchmarks.evaluate(_result(&"stroop", {"interference_ms": 10.0, "error_rate": 0.1}))["level"], Benchmarks.Level.ADVANCED)
	assert_eq(Benchmarks.evaluate(_result(&"stroop", {"interference_ms": 10.0, "error_rate": 0.0}))["level"], Benchmarks.Level.ELITE)
	# Accuracy gates that require a high value.
	assert_eq(Benchmarks.evaluate(_result(&"mental_rotation", {"median_rt_ms": 600.0, "accuracy": 0.7}))["level"], Benchmarks.Level.BEGINNER)
	assert_eq(Benchmarks.evaluate(_result(&"mental_rotation", {"median_rt_ms": 600.0, "accuracy": 1.0}))["level"], Benchmarks.Level.ELITE)


func test_variants_and_missing_data() -> void:
	assert_eq(Benchmarks.evaluate(_result(&"schulte_table", {"total_ms": 19000.0, "errors": 0.0}, {"grid_size": 5, "red_black": false, "symbols": "numbers", "test_mode": false}))["level"], Benchmarks.Level.ELITE)
	assert_true(Benchmarks.evaluate(_result(&"schulte_table", {"total_ms": 19000.0, "errors": 0.0}, {"grid_size": 3, "red_black": false, "symbols": "numbers", "test_mode": false})).is_empty())
	assert_eq(Benchmarks.evaluate(_result(&"schulte_table", {"total_ms": 80000.0, "errors": 1.0}, {"grid_size": 7, "red_black": true, "test_mode": false}))["level"], Benchmarks.Level.ADVANCED)
	assert_eq(Benchmarks.evaluate(_result(&"digit_span", {"span": 6.0, "backward": 1.0}, {"backward": true}))["level"], Benchmarks.Level.ADVANCED)
	assert_true(Benchmarks.evaluate(_result(&"visual_masking", {"threshold_ms": -1.0})).is_empty())
	assert_true(Benchmarks.evaluate(_result(&"okn_stripes", {"detection_rate": 1.0})).is_empty())


func test_n_back_levels() -> void:
	assert_eq(Benchmarks.evaluate(_result(&"n_back", {"level": 1.0, "accuracy": 0.95}))["level"], Benchmarks.Level.BEGINNER)
	assert_eq(Benchmarks.evaluate(_result(&"n_back", {"level": 2.0, "accuracy": 0.92}))["level"], Benchmarks.Level.ADVANCED)
	assert_eq(Benchmarks.evaluate(_result(&"n_back", {"level": 3.0, "accuracy": 0.95}))["level"], Benchmarks.Level.ELITE)


func test_format_bound() -> void:
	assert_eq(Benchmarks.format_bound(20000.0, "s"), Format.seconds(20000))
	assert_eq(Benchmarks.format_bound(0.94, "%"), "94 %")
	assert_eq(Benchmarks.format_bound(8.0, ""), "8")


func test_config_match_across_types() -> void:
	var r := DrillResult.new()
	r.drill_id = &"schulte_table"
	r.config = {"grid": 5, "symbols": "numbers"}
	r.metrics = {"total_ms": 15000.0}
	assert_true(Benchmarks.evaluate(r).is_empty(), "a config without grid_size matches no entry and must not raise")
	r.config = {"grid_size": 5.0, "symbols": "numbers"}
	assert_eq(Benchmarks.evaluate(r).get("level"), Benchmarks.Level.ELITE, "a float from JSON matches the int requirement; missing flags count as off")
	r.config = {"grid_size": 5, "symbols": "numbers", "red_black": true}
	var verdict := Benchmarks.evaluate(r)
	assert_eq(verdict.get("metric"), "total_ms")
	assert_true(verdict.has("level"))
