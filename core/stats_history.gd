## In-memory history of drill runs: one Dictionary per run, oldest first.
## Pure logic (no files); StatsStore persists it as JSON Lines.
class_name StatsHistory
extends RefCounted

const TREND_WINDOW := 10
const SPARKLINE_RUNS := 20

var records: Array[Dictionary] = []


## Builds the stored record of a result: identity, the primary value and the
## derived statistics, plus the raw metrics and details for later analysis.
static func make_record(result: DrillResult) -> Dictionary:
	var primary := MetricCatalog.primary_of(result.drill_id)
	var verdict := Benchmarks.evaluate(result)
	var level: int = verdict.get("level", Benchmarks.Level.NONE)
	return {
		"id": "%d-%d" % [result.finished_at_unix, randi() % 1000000],
		"at": result.finished_at_unix,
		"drill_id": String(result.drill_id),
		"variant": MetricCatalog.variant_key(result.drill_id, result.config),
		"config": result.config.duplicate(),
		"metric": primary.get("metric", ""),
		"lower": primary.get("lower", true),
		"unit": primary.get("unit", ""),
		"value": _or_null(MetricCatalog.primary_value(result)),
		"error_count": result.error_count,
		"total_ms": result.total_ms,
		"variability_ms": _or_null(MetricCatalog.variability_ms(result.details)),
		"fatigue": _or_null(MetricCatalog.fatigue_index(result.details)),
		"level": level,
		"rpe": 0,
		"metrics": result.metrics.duplicate(),
		"details": result.details.duplicate(true),
	}


func add(record: Dictionary) -> void:
	records.append(record)


func find(id: String) -> Dictionary:
	for record in records:
		if record["id"] == id:
			return record
	return {}


func set_rpe(id: String, rpe: int) -> bool:
	var record := find(id)
	if record.is_empty():
		return false
	record["rpe"] = rpe
	return true


## Runs of one variant with a usable primary value, oldest first.
func for_variant(variant: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for record in records:
		if record["variant"] == variant and _has_value(record):
			out.append(record)
	return out


## Variants that have at least one run with a usable value, most recently played first.
func variants() -> Array[String]:
	var last_at: Dictionary = {}
	for record in records:
		if not _has_value(record):
			continue
		var variant: String = record["variant"]
		var at: int = record["at"]
		var known: int = last_at.get(variant, -1)
		if known < at:
			last_at[variant] = at
	var out: Array[String] = []
	for key: String in last_at:
		out.append(key)
	out.sort_custom(func(a: String, b: String) -> bool:
		var at_a: int = last_at[a]
		var at_b: int = last_at[b]
		return at_a > at_b)
	return out


## How [param record] compares with the earlier runs of its variant:
## {"runs": int (including this one), "previous_mean": float or NAN,
## "previous_count": int, "delta": value - previous_mean (NAN without history),
## "improved": bool, "best": best earlier value or NAN, "is_best": bool}.
func summary(record: Dictionary, window: int = TREND_WINDOW) -> Dictionary:
	var lower: bool = record["lower"]
	var value := number(record, "value")
	var variant: String = record["variant"]
	var earlier: Array[Dictionary] = []
	for other in for_variant(variant):
		if other["id"] == record["id"]:
			break
		earlier.append(other)
	var out := {"runs": earlier.size() + 1, "previous_mean": NAN, "previous_count": 0, "delta": NAN, "improved": false, "best": NAN, "is_best": false}
	if earlier.is_empty() or is_nan(value):
		out["is_best"] = not is_nan(value)
		return out
	var start := maxi(0, earlier.size() - window)
	var total := 0.0
	for i in range(start, earlier.size()):
		var v: float = earlier[i]["value"]
		total += v
	var count := earlier.size() - start
	var previous_mean := total / count
	var best: float = earlier[0]["value"]
	for other in earlier:
		var v: float = other["value"]
		best = minf(best, v) if lower else maxf(best, v)
	out["previous_mean"] = previous_mean
	out["previous_count"] = count
	out["delta"] = value - previous_mean
	out["improved"] = value < previous_mean if lower else value > previous_mean
	out["best"] = best
	out["is_best"] = value < best if lower else value > best
	return out


## Aggregate for the progress screen: {"runs", "last", "best", "recent_mean",
## "change" (recent window mean minus the window before it, NAN when there is
## no earlier window), "last_level", "values" and "dates" (last SPARKLINE_RUNS runs)}.
func overview(variant: String, window: int = TREND_WINDOW) -> Dictionary:
	var runs := for_variant(variant)
	if runs.is_empty():
		return {}
	var lower: bool = runs[0]["lower"]
	var values := PackedFloat64Array()
	var ats := PackedInt64Array()
	var best: float = runs[0]["value"]
	for run in runs:
		var v: float = run["value"]
		var at: int = run["at"]
		values.append(v)
		ats.append(at)
		best = minf(best, v) if lower else maxf(best, v)
	var recent_start := maxi(0, values.size() - window)
	var recent_mean := _mean(values, recent_start, values.size())
	var change := NAN
	if recent_start > 0:
		change = recent_mean - _mean(values, maxi(0, recent_start - window), recent_start)
	var last := runs[runs.size() - 1]
	return {
		"runs": runs.size(),
		"last": last["value"],
		"last_at": last["at"],
		"best": best,
		"recent_mean": recent_mean,
		"change": change,
		"last_level": last["level"],
		"lower": lower,
		"unit": last["unit"],
		"values": values.slice(maxi(0, values.size() - SPARKLINE_RUNS)),
		"dates": ats.slice(maxi(0, ats.size() - SPARKLINE_RUNS)),
	}


## Activity of the last seven days: {"runs", "minutes" (sum of run times),
## "drills" (distinct drill ids), "improved" (variants whose latest run in
## the window beat the mean of the runs before it)}.
func week_summary(now_unix: int) -> Dictionary:
	var since := now_unix - 7 * 86400
	var runs := 0
	var total_ms := 0
	var drills: Dictionary = {}
	var latest_in_window: Dictionary = {}
	for record in records:
		var at: int = record["at"]
		if at < since:
			continue
		runs += 1
		var ms: int = record.get("total_ms", 0)
		total_ms += ms
		drills[record["drill_id"]] = true
		if _has_value(record):
			latest_in_window[record["variant"]] = record
	var improved := 0
	for variant: String in latest_in_window:
		var record: Dictionary = latest_in_window[variant]
		var s := summary(record)
		var delta: float = s["delta"]
		if not is_nan(delta) and s["improved"]:
			improved += 1
	return {"runs": runs, "minutes": roundi(total_ms / 60000.0), "drills": drills.size(), "improved": improved}


func serialize() -> String:
	var lines := PackedStringArray()
	for record in records:
		lines.append(JSON.stringify(record))
	return "\n".join(lines) + ("\n" if not lines.is_empty() else "")


const CSV_COLUMNS: PackedStringArray = ["at", "drill_id", "variant", "metric", "value", "unit", "error_count", "total_ms", "variability_ms", "fatigue", "level", "rpe"]


## Flat CSV of the stored runs (one row per run, the columns above, ISO date
## first) for spreadsheets; raw details stay in the JSON Lines file.
func to_csv() -> String:
	var lines := PackedStringArray()
	var header := PackedStringArray(["date"])
	header.append_array(CSV_COLUMNS)
	lines.append(",".join(header))
	for record in records:
		var at: int = record["at"]
		var cells := PackedStringArray([Time.get_datetime_string_from_unix_time(at)])
		for column in CSV_COLUMNS:
			cells.append(_csv_cell(record.get(column)))
		lines.append(",".join(cells))
	return "\n".join(lines) + "\n"


static func _csv_cell(value: Variant) -> String:
	if value == null:
		return ""
	if value is float:
		var f: float = value
		return "%d" % roundi(f) if f == floorf(f) else "%.3f" % f
	var text := str(value)
	if text.contains(",") or text.contains("\"") or text.contains("\n"):
		return "\"%s\"" % text.replace("\"", "\"\"")
	return text


static func serialize_record(record: Dictionary) -> String:
	return JSON.stringify(record) + "\n"


## Parses JSON Lines; malformed lines are skipped.
static func parse(text: String) -> StatsHistory:
	var history := StatsHistory.new()
	for line in text.split("\n", false):
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			var record: Dictionary = parsed
			if record.has("id") and record.has("variant") and record.has("value"):
				var at: float = record.get("at", 0.0)
				var level: float = record.get("level", -1.0)
				var rpe: float = record.get("rpe", 0.0)
				record["at"] = int(at)
				record["level"] = int(level)
				record["rpe"] = int(rpe)
				history.records.append(record)
	return history


## JSON has no NaN, so a missing number is stored as null.
static func _or_null(value: float) -> Variant:
	return null if is_nan(value) else value


## Reads a stored number that may be null.
static func number(record: Dictionary, key: String) -> float:
	var value: Variant = record.get(key)
	if value is float or value is int:
		return value
	return NAN


static func _has_value(record: Dictionary) -> bool:
	var value: Variant = record["value"]
	if value is int:
		return true
	if value is float:
		var f: float = value
		return not is_nan(f)
	return false


static func _mean(values: PackedFloat64Array, from: int, to: int) -> float:
	var total := 0.0
	for i in range(from, to):
		total += values[i]
	return total / maxi(1, to - from)
