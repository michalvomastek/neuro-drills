## Lists the registered drills and offers a language toggle.
extends Control

@onready var _drill_list: GridContainer = %DrillList
@onready var _language_button: Button = %LanguageButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	var first_button: Button = null
	for category in DrillRegistry.CATEGORY_ORDER:
		var definitions := DrillRegistry.get_by_category(category)
		if definitions.is_empty():
			continue
		_add_category_header(category)
		for definition in definitions:
			var button := _add_drill_entry(definition)
			if first_button == null:
				first_button = button
	_language_button.pressed.connect(_on_language_pressed)
	_quit_button.pressed.connect(get_tree().quit)
	_quit_button.visible = not OS.has_feature("web")
	if first_button != null:
		first_button.grab_focus()


## A header row spanning both grid columns.
func _add_category_header(category_key: String) -> void:
	var header := Label.new()
	header.text = tr(category_key)
	header.theme_type_variation = &"DimLabel"
	header.add_theme_font_size_override("font_size", 22)
	_drill_list.add_child(header)
	_drill_list.add_child(Control.new())


func _add_drill_entry(definition: DrillDefinition) -> Button:
	var entry := VBoxContainer.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_theme_constant_override("separation", 4)
	var button := Button.new()
	button.text = tr(definition.title_key)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.theme_type_variation = &"PrimaryButton"
	button.pressed.connect(SceneRouter.start_drill.bind(definition.id))
	entry.add_child(button)
	var description := Label.new()
	description.text = tr(definition.description_key)
	description.theme_type_variation = &"DimLabel"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(0, 0)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_child(description)
	_drill_list.add_child(entry)
	return button


func _on_language_pressed() -> void:
	var next_locale := "en" if TranslationServer.get_locale().begins_with("cs") else "cs"
	TranslationServer.set_locale(next_locale)
	# Texts set from code do not retranslate on their own; rebuild the screen.
	SceneRouter.show_menu()
