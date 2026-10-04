## Settings of one Schulte table run. Converts to and from a plain Dictionary
## so the configuration travels inside DrillResult and can be persisted.
class_name SchulteConfig
extends RefCounted

const MIN_GRID_SIZE := 3
const MAX_GRID_SIZE := 7
const DEFAULT_GRID_SIZE := 5

var grid_size: int = DEFAULT_GRID_SIZE
var countdown: bool = true
var fixation_dot: bool = false
var show_next_target: bool = false
var dim_found: bool = false


static func from_dict(data: Dictionary) -> SchulteConfig:
	var config := SchulteConfig.new()
	if data.has("grid_size"):
		var requested: int = data["grid_size"]
		config.grid_size = clampi(requested, MIN_GRID_SIZE, MAX_GRID_SIZE)
	config.countdown = data.get("countdown", config.countdown)
	config.fixation_dot = data.get("fixation_dot", config.fixation_dot)
	config.show_next_target = data.get("show_next_target", config.show_next_target)
	config.dim_found = data.get("dim_found", config.dim_found)
	return config


func to_dict() -> Dictionary:
	return {
		"grid_size": grid_size,
		"countdown": countdown,
		"fixation_dot": fixation_dot,
		"show_next_target": show_next_target,
		"dim_found": dim_found,
	}
