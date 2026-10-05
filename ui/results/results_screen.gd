## Shows one DrillResult and offers to repeat the run, change its settings or leave.
class_name ResultsScreen
extends Control

@onready var _heading_label: Label = %HeadingLabel
@onready var _title_label: Label = %TitleLabel
@onready var _rows: GridContainer = %Rows
@onready var _detail_rows: GridContainer = %DetailRows
@onready var _more_button: Button = %MoreButton
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
	_more_button.pressed.connect(_on_more_pressed)
	Layout.watch(self, _relayout)


## The label column gets three fifths of a phone's width so most labels fit
## on one line; a wide panel lets the value column take its natural width.
const BADGE_ICON_SIZE := 32.0


func _size_row(label: Label, value_label: Label) -> void:
	var narrow := Layout.is_narrow(self)
	label.size_flags_stretch_ratio = 3.0
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_SHRINK_END
	value_label.size_flags_stretch_ratio = 2.0
	# Wrapping needs a width to wrap to; a shrinking column would wrap per letter.
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if narrow else TextServer.AUTOWRAP_OFF


## On a phone the panel takes the whole width, the RPE buttons drop under
## their label and the four buttons form two rows.
func _relayout() -> void:
	var narrow := Layout.is_narrow(self)
	_vbox.custom_minimum_size = Vector2(Layout.panel_width(self, 520.0), 0)
	_vbox.add_theme_constant_override("separation", 10 if narrow else 16)
	_rpe_box.vertical = narrow
	_rpe_buttons.columns = 5 if narrow else 10
	for grid: GridContainer in [_rows, _detail_rows]:
		grid.add_theme_constant_override("h_separation", 12 if narrow else 32)
		grid.add_theme_constant_override("v_separation", 4 if narrow else 8)
		for i in range(0, grid.get_child_count() - 1, 2):
			_size_row(grid.get_child(i) as Label, grid.get_child(i + 1) as Label)
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
	_add_stable_best_row(_record)
	_add_reward_rows(_record)
	_build_rpe_row()
	_apply_training_mode()
	_more_button.visible = _detail_rows.get_child_count() > 0
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


## For staircase drills: the mean of the best 3 runs of the last 5 days.
func _add_stable_best_row(record: Dictionary) -> void:
	var drill_id: String = record["drill_id"]
	if not MetricCatalog.THRESHOLD_DRILLS.has(drill_id):
		return
	var variant: String = record["variant"]
	var stable := StatsStore.history.stable_best(variant, int(Time.get_unix_time_from_system()))
	if is_nan(stable):
		return
	var unit: String = record["unit"]
	_add_row("RESULT_STABLE_BEST", MetricCatalog.format_value(stable, unit), true)


## Points for this run and any badge earned by it.
func _add_reward_rows(record: Dictionary) -> void:
	_add_row("RESULT_XP", tr("RESULT_XP_VALUE") % Gamification.xp_for_record(record))
	for id in StatsStore.take_new_badges():
		_add_badge_row(id)


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
		_add_row("RESULT_NEXT_LEVEL", "%s: %s" % [tr(next_key), Benchmarks.format_bound(next, unit)], true)


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
		_add_row("RESULT_VARIABILITY", Format.millis(variability), true)
	var fatigue := StatsHistory.number(record, "fatigue")
	if not is_nan(fatigue):
		_add_row("RESULT_FATIGUE", Format.ratio(fatigue), true)


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
		button.theme_type_variation = &"SmallPrimaryButton" if button.button_pressed else &"SmallButton"
	var id: String = _record["id"]
	StatsStore.set_rpe(id, rpe)


## The main grid holds what the player looks for first; [param detail] rows
## go to the collapsible section under "More" so a phone shows the result
## without scrolling.
func _add_row(label_key: String, value: String, detail: bool = false) -> void:
	var grid := _detail_rows if detail else _rows
	var label := Label.new()
	label.text = tr(label_key)
	label.theme_type_variation = &"DimLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grid.add_child(label)
	var value_label := Label.new()
	value_label.text = tr(value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(value_label)
	_size_row(label, value_label)


## "New badge" with the medallion next to its name.
func _add_badge_row(id: String) -> void:
	var label := Label.new()
	label.text = tr("RESULT_NEW_BADGE")
	label.theme_type_variation = &"DimLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(label)
	var value := HBoxContainer.new()
	value.alignment = BoxContainer.ALIGNMENT_END
	value.add_theme_constant_override("separation", 8)
	var icon := GamiWidgets.make_badge_icon(id, BADGE_ICON_SIZE, true)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.add_child(icon)
	var name := Label.new()
	name.text = tr("BADGE_%s" % id.to_upper())
	name.theme_type_variation = &"PillLabel"
	name.add_theme_font_size_override("font_size", 18)
	name.add_theme_color_override("font_color", get_theme_color("yellow", "App"))
	value.add_child(name)
	_rows.add_child(value)
	_size_row(label, name)
	value.size_flags_horizontal = name.size_flags_horizontal
	value.size_flags_stretch_ratio = name.size_flags_stretch_ratio
	name.size_flags_horizontal = Control.SIZE_SHRINK_END
	name.autowrap_mode = TextServer.AUTOWRAP_OFF


func _on_more_pressed() -> void:
	_detail_rows.visible = not _detail_rows.visible
	_more_button.text = tr("RESULT_LESS" if _detail_rows.visible else "RESULT_MORE")


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
