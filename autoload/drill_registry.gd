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
