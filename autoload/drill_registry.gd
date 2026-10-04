## App-wide list of available drills. Adding a drill means adding one entry here.
extends Node

var _definitions: Array[DrillDefinition] = []


func _init() -> void:
	register(DrillDefinition.new(
		&"schulte_table",
		"SCHULTE_TITLE",
		"SCHULTE_DESCRIPTION",
		"res://drills/schulte_table/schulte_table.tscn",
	))
	register(DrillDefinition.new(&"reaction_time", "REACTION_TITLE", "REACTION_DESCRIPTION",
		"res://drills/reaction_time/reaction_time.tscn"))
	register(DrillDefinition.new(&"choice_reaction", "CHOICE_TITLE", "CHOICE_DESCRIPTION",
		"res://drills/choice_reaction/choice_reaction.tscn"))
	register(DrillDefinition.new(&"go_no_go", "GONOGO_TITLE", "GONOGO_DESCRIPTION",
		"res://drills/go_no_go/go_no_go.tscn"))
	register(DrillDefinition.new(&"stroop", "STROOP_TITLE", "STROOP_DESCRIPTION",
		"res://drills/stroop/stroop.tscn"))
	register(DrillDefinition.new(&"flanker", "FLANKER_TITLE", "FLANKER_DESCRIPTION",
		"res://drills/flanker/flanker.tscn"))
	register(DrillDefinition.new(&"n_back", "NBACK_TITLE", "NBACK_DESCRIPTION",
		"res://drills/n_back/n_back.tscn"))
	register(DrillDefinition.new(&"corsi_blocks", "CORSI_TITLE", "CORSI_DESCRIPTION",
		"res://drills/corsi_blocks/corsi_blocks.tscn"))
	register(DrillDefinition.new(&"digit_span", "DIGIT_TITLE", "DIGIT_DESCRIPTION",
		"res://drills/digit_span/digit_span.tscn"))
	register(DrillDefinition.new(&"memory_matrix", "MATRIX_TITLE", "MATRIX_DESCRIPTION",
		"res://drills/memory_matrix/memory_matrix.tscn"))
	register(DrillDefinition.new(&"simon", "SIMON_TITLE", "SIMON_DESCRIPTION",
		"res://drills/simon/simon.tscn"))
	register(DrillDefinition.new(&"trail_making", "TRAIL_TITLE", "TRAIL_DESCRIPTION",
		"res://drills/trail_making/trail_making.tscn"))
	register(DrillDefinition.new(&"visual_search", "SEARCH_TITLE", "SEARCH_DESCRIPTION",
		"res://drills/visual_search/visual_search.tscn"))
	register(DrillDefinition.new(&"sart", "SART_TITLE", "SART_DESCRIPTION",
		"res://drills/sart/sart.tscn"))
	register(DrillDefinition.new(&"task_switching", "SWITCH_TITLE", "SWITCH_DESCRIPTION",
		"res://drills/task_switching/task_switching.tscn"))
	register(DrillDefinition.new(&"rsvp_reading", "RSVP_TITLE", "RSVP_DESCRIPTION",
		"res://drills/rsvp_reading/rsvp_reading.tscn"))
	register(DrillDefinition.new(&"number_pyramid", "PYRAMID_TITLE", "PYRAMID_DESCRIPTION",
		"res://drills/number_pyramid/number_pyramid.tscn"))
	register(DrillDefinition.new(&"flash_number", "FLASH_TITLE", "FLASH_DESCRIPTION",
		"res://drills/flash_number/flash_number.tscn"))
	register(DrillDefinition.new(&"arithmetic", "ARITH_TITLE", "ARITH_DESCRIPTION",
		"res://drills/arithmetic/arithmetic.tscn"))


func register(definition: DrillDefinition) -> void:
	_definitions.append(definition)


func get_all() -> Array[DrillDefinition]:
	return _definitions.duplicate()


## Returns null when no drill has that id.
func find(id: StringName) -> DrillDefinition:
	for definition in _definitions:
		if definition.id == id:
			return definition
	return null
