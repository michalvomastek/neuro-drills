## Simon: a colour sequence grows by one each round and must be repeated.
class_name SimonLogic
extends RefCounted

const PAD_COUNT := 4
const MAX_LENGTH := 20

var sequence: Array[int] = []
var step: int = 0
var failed: bool = false
var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


## Adds one pad to the sequence and restarts the input position.
func extend() -> Array[int]:
	sequence.append(_rng.randi_range(0, PAD_COUNT - 1))
	step = 0
	return sequence


## Checks the next pad of the player's reply; returns false on a mistake.
func press(pad: int) -> bool:
	if pad != sequence[step]:
		failed = true
		return false
	step += 1
	return true


func round_complete() -> bool:
	return step >= sequence.size()


func is_done() -> bool:
	return failed or sequence.size() >= MAX_LENGTH and round_complete()


## Longest sequence repeated correctly.
func best_length() -> int:
	return sequence.size() - 1 if failed else sequence.size()


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.error_count = 1 if failed else 0
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["RESULT_SEQUENCE_LENGTH", str(best_length())]),
	]
	result.details = {"best_length": best_length(), "failed": failed}
	result.metrics = {"best_length": float(best_length())}
	return result
