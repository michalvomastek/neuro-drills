## Shows one DrillResult and offers to repeat the run, change its settings or leave.
class_name ResultsScreen
extends Control

@onready var _title_label: Label = %TitleLabel
@onready var _rows: GridContainer = %Rows
@onready var _again_button: Button = %AgainButton
@onready var _settings_button: Button = %SettingsButton
@onready var _menu_button: Button = %MenuButton
@onready var _rpe_box: HBoxContainer = %RpeBox
@onready var _rpe_buttons: HBoxContainer = %RpeButtons

var _result: DrillResult
var _record: Dictionary = {}
var _rpe_group := ButtonGroup.new()


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
	_add_benchmark_rows(result)
	_record = StatsStore.record(result)
	_add_history_rows(_record)
	_build_rpe_row()
	_again_button.grab_focus()


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
	_rows.add_child(label)
	var value_label := Label.new()
	value_label.text = tr(value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rows.add_child(value_label)


func _on_again_pressed() -> void:
	SceneRouter.start_drill(_result.drill_id, _result.config, true)


func _on_settings_pressed() -> void:
	SceneRouter.start_drill(_result.drill_id, _result.config, false)
