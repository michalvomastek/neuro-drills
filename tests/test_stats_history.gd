extends TestCase


func _result(id: StringName, metrics: Dictionary, config: Dictionary = {}, details: Dictionary = {}, at: int = 0) -> DrillResult:
	var r := DrillResult.new()
	r.drill_id = id
	r.metrics = metrics
	r.config = config
	r.details = details
	r.finished_at_unix = at
	return r


func test_variant_key_ignores_cosmetic_options() -> void:
	var a := MetricCatalog.variant_key(&"schulte_table", {"grid_size": 5, "symbols": "numbers", "countdown": true, "show_timer": false})
	var b := MetricCatalog.variant_key(&"schulte_table", {"symbols": "numbers", "grid_size": 5, "countdown": false, "show_timer": true})
	assert_eq(a, b)
	assert_eq(a, "schulte_table|grid_size=5|symbols=numbers")
	assert_eq(MetricCatalog.variant_key(&"reaction_time", {"trials": 20, "countdown": true}), "reaction_time")
	assert_eq(MetricCatalog.variant_key(&"trail_making", {"trials": 20, "order": 2}), "trail_making|order=2|trials=20")
	assert_eq(MetricCatalog.variant_key(&"schulte_table", {"grid_size": 5.0}), "schulte_table|grid_size=5", "floats from JSON read as ints")
	assert_eq(MetricCatalog.variant_key(&"schulte_table", {"grid_size": 7, "red_black": true, "reverse": false}), "schulte_table|grid_size=7|red_black=true")
	TranslationServer.set_locale("en")
	assert_eq(MetricCatalog.variant_label("schulte_table|grid_size=7|red_black=true"), "7×7 · red-black")
	assert_eq(MetricCatalog.variant_label("trail_making|order=2|trials=20"), "Numbers ascending + letters descending (1-C-2-B-3-A) · 20 items")
	assert_eq(MetricCatalog.variant_label("n_back|n=2"), "2-back")
	assert_eq(MetricCatalog.variant_label("mystery|odd_flag=true|knob=3"), "odd flag · knob 3", "unknown options fall back to the raw key")
	assert_eq(MetricCatalog.variant_label("reaction_time"), "")
	assert_eq(MetricCatalog.drill_id_of("trail_making|order=2"), &"trail_making")


func test_every_drill_has_a_primary_metric() -> void:
	var ids: Array[StringName] = []
	for drill_id: String in Benchmarks.TABLE:
		ids.append(StringName(drill_id))
	for drill_id in ids:
		assert_false(MetricCatalog.primary_of(drill_id).is_empty(), String(drill_id))
	assert_eq(MetricCatalog.PRIMARY.size(), 43)


func test_fatigue_and_variability() -> void:
	var plain := {"times_ms": [300, 300, 300, 310, 310, 310, 360, 360, 360]}
	assert_true(absf(MetricCatalog.fatigue_index(plain) - 1.2) < 0.001)
	assert_true(MetricCatalog.variability_ms(plain) > 25.0 and MetricCatalog.variability_ms(plain) < 30.0)
	var cumulative := {"found_at_ms": [100, 200, 300, 400, 500, 600, 800, 1000, 1200]}
	assert_true(absf(MetricCatalog.fatigue_index(cumulative) - 2.0) < 0.001, "intervals 100,100,100 vs 200,200,200")
	assert_true(is_nan(MetricCatalog.fatigue_index({"times_ms": [1, 2, 3]})))
	assert_true(is_nan(MetricCatalog.fatigue_index({"span": 5})))


func test_summary_trend_and_best() -> void:
	var history := StatsHistory.new()
	for i in 3:
		history.add(StatsHistory.make_record(_result(&"reaction_time", {"median_rt_ms": 300.0 - 10 * i}, {"trials": 20}, {}, 1000 + i)))
	var fresh := StatsHistory.make_record(_result(&"reaction_time", {"median_rt_ms": 250.0}, {"trials": 30, "countdown": false}, {}, 2000))
	history.add(fresh)
	var s := history.summary(fresh)
	assert_eq(s["runs"], 4)
	assert_eq(s["previous_count"], 3)
	var previous_mean: float = s["previous_mean"]
	var delta: float = s["delta"]
	assert_true(absf(previous_mean - 290.0) < 0.001)
	assert_true(absf(delta + 40.0) < 0.001)
	assert_eq(s["improved"], true)
	assert_eq(s["is_best"], true)
	assert_eq(s["best"], 280.0)
	# Higher is better: a worse span is neither improvement nor record.
	var span_history := StatsHistory.new()
	span_history.add(StatsHistory.make_record(_result(&"corsi_blocks", {"span": 7.0}, {}, {}, 1)))
	var worse := StatsHistory.make_record(_result(&"corsi_blocks", {"span": 6.0}, {}, {}, 2))
	span_history.add(worse)
	var w := span_history.summary(worse)
	assert_eq(w["improved"], false)
	assert_eq(w["is_best"], false)
	# A first run of a variant is a record by definition and has no delta.
	var first := StatsHistory.make_record(_result(&"stroop", {"interference_ms": 50.0}, {}, {}, 3))
	history.add(first)
	var f := history.summary(first)
	assert_eq(f["runs"], 1)
	var first_delta: float = f["delta"]
	assert_true(is_nan(first_delta))
	assert_eq(f["is_best"], true)


func test_unusable_values() -> void:
	# A negative interference is a real (excellent) result; 0 ms reaction and -1 threshold are not.
	assert_eq(MetricCatalog.primary_value(_result(&"stroop", {"interference_ms": -12.0, "error_rate": 0.0})), -12.0)
	assert_eq(Benchmarks.evaluate(_result(&"stroop", {"interference_ms": -12.0, "error_rate": 0.0}))["level"], Benchmarks.Level.ELITE)
	assert_true(is_nan(MetricCatalog.primary_value(_result(&"reaction_time", {"median_rt_ms": 0.0}))))
	assert_true(Benchmarks.evaluate(_result(&"reaction_time", {"median_rt_ms": 0.0})).is_empty())
	assert_true(is_nan(MetricCatalog.primary_value(_result(&"visual_masking", {"threshold_ms": -1.0}))))
	var history := StatsHistory.new()
	history.add(StatsHistory.make_record(_result(&"visual_masking", {"threshold_ms": -1.0}, {}, {}, 1)))
	assert_true(history.variants().is_empty(), "a variant without a usable run is not listed")
	history.add(StatsHistory.make_record(_result(&"visual_masking", {"threshold_ms": 50.0}, {}, {}, 2)))
	assert_eq(history.variants(), ["visual_masking"] as Array[String])
	assert_eq(history.overview("visual_masking")["runs"], 1)


func test_overview_and_variants_order() -> void:
	var history := StatsHistory.new()
	for i in 25:
		history.add(StatsHistory.make_record(_result(&"reaction_time", {"median_rt_ms": 300.0 - i}, {}, {}, 100 + i)))
	history.add(StatsHistory.make_record(_result(&"corsi_blocks", {"span": 6.0}, {}, {}, 50)))
	var variants := history.variants()
	assert_eq(variants, ["reaction_time", "corsi_blocks"] as Array[String])
	var o := history.overview("reaction_time")
	assert_eq(o["runs"], 25)
	assert_eq(o["last"], 276.0)
	assert_eq(o["best"], 276.0)
	assert_eq((o["values"] as PackedFloat64Array).size(), StatsHistory.SPARKLINE_RUNS)
	var change: float = o["change"]
	assert_true(absf(change + 10.0) < 0.001, "last ten vs the ten before")
	assert_true(history.overview("unknown").is_empty())


func test_serialize_roundtrip_and_rpe() -> void:
	var history := StatsHistory.new()
	var record := StatsHistory.make_record(_result(&"reaction_time", {"median_rt_ms": 250.0}, {"trials": 20}, {"times_ms": [240, 250, 260]}, 1234))
	history.add(record)
	var id: String = record["id"]
	assert_true(history.set_rpe(id, 7))
	assert_false(history.set_rpe("missing", 7))
	var text := history.serialize() + "{\"foo\": 1}\n\n"
	var loaded := StatsHistory.parse(text)
	assert_eq(loaded.records.size(), 1)
	var back := loaded.records[0]
	assert_eq(back["id"], record["id"])
	assert_eq(back["rpe"], 7)
	assert_eq(back["at"], 1234)
	assert_eq(back["variant"], "reaction_time")
	assert_eq(back["value"], 250.0)
	assert_eq(loaded.summary(back)["runs"], 1)
	# A record whose variability is NAN survives the round trip as "no value".
	var sparse := StatsHistory.make_record(_result(&"corsi_blocks", {"span": 5.0}, {}, {}, 1))
	history.add(sparse)
	var csv := history.to_csv()
	var rows := csv.split("\n", false)
	assert_eq(rows.size(), 3)
	assert_eq(rows[0], "date,at,drill_id,variant,metric,value,unit,error_count,total_ms,variability_ms,fatigue,level,rpe")
	assert_true(rows[1].begins_with("1970-01-01T00:20:34,1234,reaction_time,reaction_time,median_rt_ms,250,ms,0,0,"), rows[1])
	assert_true(rows[1].ends_with(",1,7"), rows[1])
	assert_true(rows[2].contains(",corsi_blocks,corsi_blocks,span,5,,0,0,,,"), rows[2])
	var again := StatsHistory.parse(history.serialize())
	assert_eq(again.records.size(), 2)
	assert_true(is_nan(StatsHistory.number(again.records[1], "variability_ms")))
	assert_eq(again.for_variant("corsi_blocks").size(), 1)
