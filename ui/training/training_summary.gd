## End of a training: total time and one row per step with its main number
## and level; offers the same plan again.
class_name TrainingSummary
extends Control

@onready var _margin: MarginContainer = %Margin
@onready var _rows: GridContainer = %Rows
@onready var _steps_grid: GridContainer = %Steps
@onready var _menu_button: Button = %MenuButton
@onready var _progress_button: Button = %ProgressButton
@onready var _again_button: Button = %AgainButton
@onready var _buttons: BoxContainer = %Buttons
@onready var _spacer: Control = %Spacer

var _session: TrainingSession


func _ready() -> void:
	_menu_button.pressed.connect(SceneRouter.show_menu)
	_progress_button.pressed.connect(SceneRouter.show_progress)
	_again_button.pressed.connect(_on_again_pressed)
	Layout.watch(self, _relayout)


func _relayout() -> void:
	var narrow := Layout.is_narrow(self)
	Layout.set_margins(_margin, Layout.side_margin(self), 12 if narrow else 32)
	_buttons.vertical = narrow
	_spacer.visible = not narrow


func setup(session: TrainingSession) -> void:
	_session = session
	_add_row(_rows, "TRAINING_SUMMARY_TIME", Format.minutes_seconds(session.elapsed_seconds()))
	_add_row(_rows, "TRAINING_SUMMARY_STEPS", "%d / %d" % [session.finished_count(), session.step_count()])
	var xp := 0
	for record in session.records:
		xp += Gamification.xp_for_record(record)
	_add_row(_rows, "TRAINING_SUMMARY_XP", tr("RESULT_XP_VALUE") % xp)
	var minutes := StatsStore.minutes_today()
	var goal := Gamification.DAILY_GOAL_MINUTES
	var goal_text := tr("TRAINING_SUMMARY_GOAL_DONE") % minutes if minutes >= goal else tr("TRAINING_SUMMARY_GOAL_LEFT") % (goal - minutes)
	_add_row(_rows, "TRAINING_SUMMARY_GOAL", goal_text)
	for record in session.records:
		var drill_id: String = record["drill_id"]
		var definition := DrillRegistry.find(StringName(drill_id))
		var title := Label.new()
		title.text = tr(definition.title_key) if definition != null else drill_id
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_steps_grid.add_child(title)
		var value := Label.new()
		var number := StatsHistory.number(record, "value")
		var unit: String = record["unit"]
		value.text = MetricCatalog.format_value(number, unit) if not is_nan(number) else "–"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_steps_grid.add_child(value)
		var level_label := Label.new()
		var level: int = record["level"]
		level_label.text = tr(Benchmarks.LEVEL_KEYS[level]) if level >= 0 else ""
		level_label.theme_type_variation = &"DimLabel"
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_steps_grid.add_child(level_label)
	_again_button.grab_focus()


func _add_row(grid: GridContainer, label_key: String, value: String) -> void:
	var label := Label.new()
	label.text = tr(label_key)
	label.theme_type_variation = &"DimLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(value_label)


func _on_again_pressed() -> void:
	SceneRouter.start_training(TrainingSession.new(_session.steps, _session.name))
