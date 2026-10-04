## Dual task: keep tapping a steady rhythm while, from a given tap on, mental
## arithmetic problems demand attention. Compares tap variability before and
## during the cognitive load.
class_name DualTaskLogic
extends RefCounted

const CUED_BEATS := 8
const BASELINE_TAPS := 12
const LOADED_TAPS := 16

var bpm: int
var taps_ms: Array[int] = []
var arithmetic: ArithmeticLogic
var problems_correct: int = 0
var problems_wrong: int = 0


func _init(p_bpm: int, rng: RandomNumberGenerator) -> void:
	bpm = p_bpm
	arithmetic = ArithmeticLogic.new(0, rng)


func period_ms() -> float:
	return 60000.0 / bpm


func total_taps() -> int:
	return CUED_BEATS + BASELINE_TAPS + LOADED_TAPS


func load_starts_at_tap() -> int:
	return CUED_BEATS + BASELINE_TAPS


func is_loaded_phase() -> bool:
	return taps_ms.size() >= load_starts_at_tap()


func record_tap(time_ms: int) -> void:
	if taps_ms.size() < total_taps():
		taps_ms.append(time_ms)


func is_done() -> bool:
	return taps_ms.size() >= total_taps()


func answer_problem(answer: int) -> bool:
	var correct := answer == arithmetic.solution()
	if correct:
		problems_correct += 1
	else:
		problems_wrong += 1
	return correct


func _intervals(from_tap: int, to_tap: int) -> Array[int]:
	var intervals: Array[int] = []
	for i in range(maxi(from_tap, 1), mini(to_tap, taps_ms.size())):
		intervals.append(taps_ms[i] - taps_ms[i - 1])
	return intervals


static func _std_dev(values: Array[int]) -> float:
	if values.size() < 2:
		return 0.0
	var sum := 0
	for v in values:
		sum += v
	var mean := float(sum) / values.size()
	var sum_sq := 0.0
	for v in values:
		sum_sq += (v - mean) * (v - mean)
	return sqrt(sum_sq / values.size())


func baseline_jitter_ms() -> float:
	return _std_dev(_intervals(CUED_BEATS, load_starts_at_tap()))


func loaded_jitter_ms() -> float:
	return _std_dev(_intervals(load_starts_at_tap(), total_taps()))


## How much worse the rhythm got under load, in percent of the baseline jitter.
func interference_percent() -> float:
	var base := baseline_jitter_ms()
	return (loaded_jitter_ms() - base) / base * 100.0 if base > 0.0 else 0.0


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(loaded_jitter_ms())
	result.error_count = problems_wrong
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["DUAL_JITTER_BASE", Format.millis(baseline_jitter_ms())]),
		PackedStringArray(["DUAL_JITTER_LOAD", Format.millis(loaded_jitter_ms())]),
		PackedStringArray(["DUAL_INTERFERENCE", "%+.0f %%" % interference_percent()]),
		PackedStringArray(["ARITH_CORRECT", "%d (%d %s)" % [problems_correct, problems_wrong, TranslationServer.translate("DUAL_WRONG_SHORT")]]),
	]
	result.details = {"taps_ms": taps_ms.duplicate(), "problems_correct": problems_correct, "problems_wrong": problems_wrong}
	result.metrics = {"interference_percent": interference_percent()}
	return result
