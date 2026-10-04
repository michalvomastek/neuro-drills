## One training in progress: the planned steps, the index of the current one
## and the stored records of the finished steps. Held by SceneRouter.
class_name TrainingSession
extends RefCounted

var name: String = ""
var steps: Array[Dictionary] = []
var index: int = 0
var records: Array[Dictionary] = []
var started_at_msec: int = 0


func _init(p_steps: Array[Dictionary], p_name: String = "") -> void:
	steps = p_steps.duplicate(true)
	name = p_name
	started_at_msec = Time.get_ticks_msec()


func current_step() -> Dictionary:
	return steps[index] if index < steps.size() else {}


func step_count() -> int:
	return steps.size()


## Steps finished so far (the current one is not counted until its record arrives).
func finished_count() -> int:
	return records.size()


func record_step(record: Dictionary) -> void:
	records.append(record)


func has_next() -> bool:
	return index + 1 < steps.size()


func advance() -> void:
	index += 1


func elapsed_seconds() -> int:
	return int((Time.get_ticks_msec() - started_at_msec) / 1000)
