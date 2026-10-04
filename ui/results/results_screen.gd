## Shows one DrillResult and offers to repeat the run, change its settings or leave.
class_name ResultsScreen
extends Control

@onready var _heading_label: Label = %HeadingLabel
@onready var _title_label: Label = %TitleLabel
@onready var _rows: GridContainer = %Rows
@onready var _again_button: Button = %AgainButton
@onready var _settings_button: Button = %SettingsButton
@onready var _menu_button: Button = %MenuButton
@onready var _rpe_box: BoxContainer = %RpeBox
@onready var _rpe_buttons: GridContainer = %RpeButtons
@onready var _note_button: Button = %NoteButton
@onready var _vbox: VBoxContainer = %VBox
@onready var _buttons: GridContainer = %Buttons
@onready var _buttons_spacer: Control = %Spacer

var _result: DrillResult
var _record: Dictionary = {}
var _rpe_group := ButtonGroup.new()


func _ready() -> void:
	_again_button.pressed.connect(_on_again_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_note_button.pressed.connect(_on_note_pressed)
	Layout.watch(self, _relayout)


## On a phone the panel takes the whole width, the RPE buttons drop under
## their label and the four buttons form two rows.
func _relayout() -> void:
	var narrow := Layout.is_narrow(self)
	_vbox.custom_minimum_size = Vector2(Layout.panel_width(self, 520.0), 0)
	_vbox.add_theme_constant_override("separation", 10 if narrow else 16)
	_rows.add_theme_constant_override("v_separation", 4 if narrow else 8)
	_rpe_box.vertical = narrow
	_rpe_buttons.columns = 5 if narrow else 10
	_rows.add_theme_constant_override("h_separation", 12 if narrow else 32)
	_buttons_spacer.visible = not narrow
	_buttons.columns = 2 if narrow else 5
	for child in _buttons.get_children():
		var button := child as Button
		if button != null:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_FILL


func setup(result: DrillResult) -> void:
	_result = result
	var definition := DrillRegistry.find(result.drill_id)
	_title_label.text = tr(definition.title_key) if definition != null else String(result.drill_id)
	for row in result.summary_rows:
		_add_row(row[0], row[1])
	_add_benchmark_rows(result)
	_record = StatsStore.record(result)
	_add_history_rows(_record)
	_add_reward_rows(_record)
	_build_rpe_row()
	_apply_training_mode()
	_again_button.grab_focus()


## Inside a training the primary button moves on to the next step (or the
## summary) and the settings button makes no sense.
func _apply_training_mode() -> void:
	var training := SceneRouter.training
	if training == null:
		return
	training.record_step(_record)
	var done := training.finished_count()
	var total := training.step_count()
	_heading_label.text = tr("TRAINING_STEP_HEADING") % [done, total]
	_settings_button.visible = false
	_again_button.text = tr("TRAINING_NEXT") % [done + 1, total] if training.has_next() else tr("TRAINING_FINISH")


## Points for this run and any badge earned by it.
func _add_reward_rows(record: Dictionary) -> void:
	_add_row("RESULT_XP", tr("RESULT_XP_VALUE") % Gamification.xp_for_record(record))
	for id in StatsStore.take_new_badges():
		_add_row("RESULT_NEW_BADGE", tr("BADGE_%s" % id.to_upper()))


## Orientational level from the benchmark table, plus the bound of the next band.
func _add_benchmark_rows(result: DrillResult) -> void:
	var verdict := Benchmarks.evaluate(result)
	if verdict.is_empty():
		return
	var level: int = verdict["level"]
	if level < 0:
		return
	_add_row("RESULT_LEVEL", tr(Benchmarks.LEVEL_KEYS[level]))
	var next: float = verdict["next"]
	if next >= 0.0:
		var unit: String = verdict["unit"]
		var next_key := Benchmarks.LEVEL_KEYS[mini(level + 1, Benchmarks.LEVEL_KEYS.size() - 1)]
		_add_row("RESULT_NEXT_LEVEL", "%s: %s" % [tr(next_key), Benchmarks.format_bound(next, unit)])


## Comparison with the earlier runs of the same variant, plus the per-run
## statistics derived from the trial times.
func _add_history_rows(record: Dictionary) -> void:
	var value := StatsHistory.number(record, "value")
	if not is_nan(value):
		var summary := StatsStore.history.summary(record)
		var runs: int = summary["runs"]
		if runs == 1:
			_add_row("RESULT_TREND", tr("RESULT_FIRST_RUN"))
		var delta: float = summary["delta"]
		var unit: String = record["unit"]
		if not is_nan(delta):
			var improved: bool = summary["improved"]
			var text := MetricCatalog.format_delta(delta, unit)
			if delta != 0.0:
				text += " (%s)" % (tr("RESULT_BETTER") if improved else tr("RESULT_WORSE"))
			_add_row("RESULT_TREND", text)
		var is_best: bool = summary["is_best"]
		if runs > 1:
			var best: float = summary["best"]
			_add_row("RESULT_BEST", tr("RESULT_NEW_BEST") if is_best else MetricCatalog.format_value(best, unit))
	var variability := StatsHistory.number(record, "variability_ms")
	if not is_nan(variability):
		_add_row("RESULT_VARIABILITY", Format.millis(variability))
	var fatigue := StatsHistory.number(record, "fatigue")
	if not is_nan(fatigue):
		_add_row("RESULT_FATIGUE", Format.ratio(fatigue))


## Ten toggle buttons for the perceived exertion; the choice is stored at once.
func _build_rpe_row() -> void:
	_rpe_box.visible = StatsStore.rpe_enabled
	if not StatsStore.rpe_enabled:
		return
	for i in range(1, 11):
		var button := Button.new()
		button.text = str(i)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_group = _rpe_group
		button.pressed.connect(_on_rpe_pressed.bind(i))
		_rpe_buttons.add_child(button)


func _on_rpe_pressed(rpe: int) -> void:
	for child in _rpe_buttons.get_children():
		var button := child as Button
		button.theme_type_variation = &"PrimaryButton" if button.button_pressed else &""
	var id: String = _record["id"]
	StatsStore.set_rpe(id, rpe)


func _add_row(label_key: String, value: String) -> void:
	var label := Label.new()
	label.text = tr(label_key)
	label.theme_type_variation = &"DimLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(label)
	var value_label := Label.new()
	value_label.text = tr(value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rows.add_child(value_label)


## Opens a small dialog for a feedback note; the result and the environment
## are attached automatically so the note explains itself later.
func _on_note_pressed() -> void:
	var dialog := NoteDialog.new(get_viewport_rect().size)
	add_child(dialog)
	dialog.open(_result_context())
	dialog.saved.connect(func() -> void: _note_button.text = tr("RESULT_NOTE_SAVED"))


func _result_context() -> Dictionary:
	var definition := DrillRegistry.find(_result.drill_id)
	var rows := PackedStringArray()
	for row in _result.summary_rows:
		rows.append("%s %s" % [tr(row[0]), tr(row[1])])
	var verdict := Benchmarks.evaluate(_result)
	var level: int = verdict.get("level", -1)
	if level >= 0:
		rows.append("%s %s" % [tr("RESULT_LEVEL"), tr(Benchmarks.LEVEL_KEYS[level])])
	var variant: String = _record.get("variant", MetricCatalog.variant_key(_result.drill_id, _result.config))
	return {
		"drill": tr(definition.title_key) if definition != null else String(_result.drill_id),
		"variant": MetricCatalog.variant_label(variant),
		"result": " · ".join(rows),
		"config": JSON.stringify(_result.config),
	}


func _on_again_pressed() -> void:
	if SceneRouter.training != null:
		SceneRouter.continue_training()
	else:
		SceneRouter.start_drill(_result.drill_id, _result.config, true)


func _on_menu_pressed() -> void:
	SceneRouter.abort_training()
	SceneRouter.show_menu()


func _on_settings_pressed() -> void:
	SceneRouter.start_drill(_result.drill_id, _result.config, false)
