## Coincidence anticipation: a disc moves at constant speed towards a target
## line and disappears behind an occluder halfway; press when it would cross.
class_name AnticipationLogic
extends RefCounted

const START_X := 0.05
const OCCLUDER_X := 0.5
const TARGET_X := 0.9
## Stage widths per second.
const SPEEDS: Array[float] = [0.25, 0.35, 0.5, 0.7]
const RESPONSE_LIMIT_MS := 2500

var trials: int
var speeds: Array[float] = []
var current: int = 0
var errors_ms: Array[int] = []
var _rng: RandomNumberGenerator


func _init(p_trials: int, rng: RandomNumberGenerator) -> void:
	trials = p_trials
	_rng = rng
	for i in trials:
		speeds.append(SPEEDS[_rng.randi_range(0, SPEEDS.size() - 1)])


func current_speed() -> float:
	return speeds[current]


## Time from the start of the trial until the disc reaches the target line.
func ideal_time_ms() -> int:
	return roundi((TARGET_X - START_X) / current_speed() * 1000.0)


## Position of the disc [param elapsed_ms] after the start.
func position_at(elapsed_ms: int) -> float:
	return START_X + current_speed() * elapsed_ms / 1000.0


## Records the press; returns the signed error (negative = too early).
func record_press(elapsed_ms: int) -> int:
	var error := elapsed_ms - ideal_time_ms()
	errors_ms.append(error)
	current += 1
	return error


func is_done() -> bool:
	return current >= trials


func mean_abs_error_ms() -> float:
	if errors_ms.is_empty():
		return 0.0
	var sum := 0
	for e in errors_ms:
		sum += absi(e)
	return float(sum) / errors_ms.size()


func mean_signed_error_ms() -> float:
	if errors_ms.is_empty():
		return 0.0
	var sum := 0
	for e in errors_ms:
		sum += e
	return float(sum) / errors_ms.size()


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = roundi(mean_abs_error_ms())
	result.error_count = 0
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	var best := 0
	if not errors_ms.is_empty():
		best = absi(errors_ms[0])
		for e in errors_ms:
			best = mini(best, absi(e))
	var bias := mean_signed_error_ms()
	var bias_key := "ANTICIPATION_EARLY" if bias < 0.0 else "ANTICIPATION_LATE"
	result.summary_rows = [
		PackedStringArray(["ANTICIPATION_MEAN_ERROR", Format.millis(mean_abs_error_ms())]),
		PackedStringArray(["ANTICIPATION_BIAS", "%s %s" % [Format.millis(absf(bias)), tr_key_bias(bias_key)]]),
		PackedStringArray(["ANTICIPATION_BEST", Format.millis(best)]),
	]
	result.details = {"errors_ms": errors_ms.duplicate()}
	result.metrics = {"mean_abs_error_ms": mean_abs_error_ms()}
	return result


## The bias direction is a translation key appended to a number; the results
## screen translates whole values only, so the key is resolved here.
static func tr_key_bias(key: String) -> String:
	return TranslationServer.translate(key)
