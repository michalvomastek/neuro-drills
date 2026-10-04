## Isochronous tapping: tap along with a visual metronome, then keep the
## tempo without it. Measures drift (tempo change) and jitter (variability).
class_name RhythmLogic
extends RefCounted

const CUED_BEATS := 8
const CONTINUATION_TAPS := 16

var bpm: int
var taps_ms: Array[int] = []


func _init(p_bpm: int) -> void:
	bpm = p_bpm


func period_ms() -> float:
	return 60000.0 / bpm


func total_taps() -> int:
	return CUED_BEATS + CONTINUATION_TAPS


func record_tap(time_ms: int) -> void:
	if taps_ms.size() < total_taps():
		taps_ms.append(time_ms)


func is_done() -> bool:
	return taps_ms.size() >= total_taps()


## Intervals between consecutive taps of the continuation phase.
func continuation_intervals() -> Array[int]:
	var intervals: Array[int] = []
	for i in range(maxi(CUED_BEATS, 1), taps_ms.size()):
		intervals.append(taps_ms[i] - taps_ms[i - 1])
	return intervals


func mean_interval_ms() -> float:
	var intervals := continuation_intervals()
	if intervals.is_empty():
		return 0.0
	var sum := 0
	for v in intervals:
		sum += v
	return float(sum) / intervals.size()


## Tempo change in percent; positive = slowing down.
func drift_percent() -> float:
	var mean := mean_interval_ms()
	return (mean - period_ms()) / period_ms() * 100.0 if mean > 0.0 else 0.0


## Standard deviation of the continuation intervals.
func jitter_ms() -> float:
	var intervals := continuation_intervals()
	if intervals.size() < 2:
		return 0.0
	var mean := mean_interval_ms()
	var sum_sq := 0.0
	for v in intervals:
		sum_sq += (v - mean) * (v - mean)
	return sqrt(sum_sq / intervals.size())


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(mean_interval_ms())
	result.error_count = 0
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["RHYTHM_TARGET", Format.millis(period_ms())]),
		PackedStringArray(["RHYTHM_MEAN", Format.millis(mean_interval_ms())]),
		PackedStringArray(["RHYTHM_DRIFT", "%+.1f %%" % drift_percent()]),
		PackedStringArray(["RHYTHM_JITTER", Format.millis(jitter_ms())]),
	]
	result.details = {"taps_ms": taps_ms.duplicate(), "drift": drift_percent(), "jitter": jitter_ms()}
	result.metrics = {"jitter_ms": jitter_ms(), "drift_percent": drift_percent()}
	return result
