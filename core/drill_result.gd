## Outcome of one drill run. Produced by a drill, consumed by the results
## screen and, later, by the statistics store. Holds only JSON-friendly values
## so it can be persisted as is.
class_name DrillResult
extends RefCounted

var drill_id: StringName
## The drill configuration that produced this result; lets the player repeat the run.
var config: Dictionary = {}
## Headline time of the run: total time for timed drills, median reaction for reaction drills.
var total_ms: int = 0
var error_count: int = 0
var finished_at_unix: int = 0
## Rows for the results screen, in order: each entry is [translation_key, value_text].
var summary_rows: Array[PackedStringArray] = []
## Drill-specific raw numbers (split times and the like) for later analysis.
var details: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"drill_id": String(drill_id),
		"config": config,
		"total_ms": total_ms,
		"error_count": error_count,
		"finished_at_unix": finished_at_unix,
		"details": details,
	}
