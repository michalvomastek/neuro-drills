## Shows one DrillResult and offers to repeat the run, change its settings or leave.
class_name ResultsScreen
extends Control

@onready var _title_label: Label = %TitleLabel
@onready var _rows: GridContainer = %Rows
@onready var _again_button: Button = %AgainButton
@onready var _settings_button: Button = %SettingsButton
@onready var _menu_button: Button = %MenuButton

var _result: DrillResult


func _ready() -> void:
	_again_button.pressed.connect(_on_again_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_menu_button.pressed.connect(SceneRouter.show_menu)


func setup(result: DrillResult) -> void:
	_result = result
	var definition := DrillRegistry.find(result.drill_id)
	_title_label.text = tr(definition.title_key) if definition != null else String(result.drill_id)
	for row in result.summary_rows:
		_add_row(row[0], row[1])
	_again_button.grab_focus()


func _add_row(label_key: String, value: String) -> void:
	var label := Label.new()
	label.text = tr(label_key)
	label.theme_type_variation = &"DimLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_child(label)
	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rows.add_child(value_label)


func _on_again_pressed() -> void:
	SceneRouter.start_drill(_result.drill_id, _result.config, true)


func _on_settings_pressed() -> void:
	SceneRouter.start_drill(_result.drill_id, _result.config, false)
