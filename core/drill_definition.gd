## Metadata the app needs to list and launch a drill without loading its scene.
class_name DrillDefinition
extends RefCounted

var id: StringName
var title_key: String
var description_key: String
var scene_path: String
## Translation key of the menu section this drill belongs to.
var category_key: String


func _init(p_id: StringName, p_title_key: String, p_description_key: String, p_scene_path: String, p_category_key: String = "CATEGORY_OTHER") -> void:
	id = p_id
	title_key = p_title_key
	description_key = p_description_key
	scene_path = p_scene_path
	category_key = p_category_key
