## Shown before every training step: which drill is next, how it is played
## and what it measures. Start launches the step with the countdown.
class_name TrainingBrief
extends Control

@onready var _vbox: VBoxContainer = %VBox
@onready var _heading_label: Label = %HeadingLabel
@onready var _title_label: Label = %TitleLabel
@onready var _variant_label: Label = %VariantLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _help_label: Label = %HelpLabel
@onready var _stop_button: Button = %StopButton
@onready var _start_button: Button = %StartButton
@onready var _spacer: Control = %Spacer


func _ready() -> void:
	_stop_button.pressed.connect(_on_stop_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	Layout.watch(self, _relayout)


func _relayout() -> void:
	_vbox.custom_minimum_size = Vector2(Layout.panel_width(self, 560.0), 0)
	_spacer.visible = not Layout.is_narrow(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_start_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_stop_pressed()
		get_viewport().set_input_as_handled()


func setup(session: TrainingSession) -> void:
	var step := session.current_step()
	var drill_id: String = step["drill_id"]
	var config: Dictionary = step["config"]
	var definition := DrillRegistry.find(StringName(drill_id))
	_heading_label.text = tr("TRAINING_STEP_HEADING") % [session.finished_count() + 1, session.step_count()]
	_title_label.text = tr(definition.title_key) if definition != null else drill_id
	var variant := MetricCatalog.variant_label(MetricCatalog.variant_key(StringName(drill_id), config))
	_variant_label.text = variant
	_variant_label.visible = not variant.is_empty()
	_description_label.text = tr(definition.description_key) if definition != null else ""
	_help_label.text = MetricCatalog.help_text(StringName(drill_id), config)
	_help_label.visible = not _help_label.text.is_empty()
	_start_button.grab_focus()


## Ends the training here; the steps played so far stay recorded in the history.
func _on_stop_pressed() -> void:
	SceneRouter.abort_training()
	SceneRouter.show_training()


## The step may be a tilt drill; iOS grants the motion sensor only inside a
## user gesture, and the drill autostarts without a tap of its own.
func _on_start_pressed() -> void:
	Drill.request_motion_permission()
	SceneRouter.start_training_step_now()
