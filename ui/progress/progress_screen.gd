## Overview of the stored runs: one entry per drill variant, with the key
## numbers of the selected variant and a sparkline of its last runs.
class_name ProgressScreen
extends Control

@onready var _list: VBoxContainer = %VariantList
@onready var _empty_label: Label = %EmptyLabel
@onready var _detail: VBoxContainer = %Detail
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_variant: Label = %DetailVariant
@onready var _rows: GridContainer = %DetailRows
@onready var _sparkline: Sparkline = %Sparkline
@onready var _rpe_check: CheckBox = %RpeCheck
@onready var _back_button: Button = %BackButton
@onready var _status_label: Label = %StatusLabel
@onready var _export_button: Button = %ExportButton
@onready var _clear_button: Button = %ClearButton
@onready var _clear_dialog: ConfirmationDialog = %ClearDialog

var _buttons: Array[Button] = []


func _ready() -> void:
	_back_button.pressed.connect(SceneRouter.show_menu)
	_rpe_check.button_pressed = StatsStore.rpe_enabled
	_rpe_check.toggled.connect(StatsStore.set_rpe_enabled)
	_export_button.pressed.connect(_on_export_pressed)
	_clear_button.pressed.connect(_clear_dialog.popup_centered)
	_clear_dialog.confirmed.connect(_on_clear_confirmed)
	_clear_dialog.ok_button_text = tr("PROGRESS_CLEAR")
	_clear_dialog.cancel_button_text = tr("COMMON_BACK")
	var variants := StatsStore.history.variants()
	_empty_label.visible = variants.is_empty()
	_detail.visible = not variants.is_empty()
	_export_button.disabled = variants.is_empty()
	_clear_button.disabled = variants.is_empty()
	for variant in variants:
		_add_variant_button(variant)
	if _buttons.is_empty():
		_back_button.grab_focus()
	else:
		_select(variants[0])
		_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneRouter.show_menu()
		get_viewport().set_input_as_handled()


func _on_export_pressed() -> void:
	var path := StatsStore.export_csv()
	_status_label.text = tr("PROGRESS_EXPORTED") % path if not path.is_empty() else tr("PROGRESS_EXPORT_FAILED")
	_status_label.tooltip_text = path


func _on_clear_confirmed() -> void:
	StatsStore.clear()
	SceneRouter.show_progress()


func _add_variant_button(variant: String) -> void:
	var button := Button.new()
	button.text = _variant_title(variant)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.pressed.connect(_select.bind(variant))
	_list.add_child(button)
	_buttons.append(button)


func _variant_title(variant: String) -> String:
	var definition := DrillRegistry.find(MetricCatalog.drill_id_of(variant))
	var title := tr(definition.title_key) if definition != null else String(MetricCatalog.drill_id_of(variant))
	var label := MetricCatalog.variant_label(variant)
	return title if label.is_empty() else "%s (%s)" % [title, label]


func _select(variant: String) -> void:
	var variants := StatsStore.history.variants()
	for i in _buttons.size():
		var selected := variants[i] == variant
		_buttons[i].button_pressed = selected
		_buttons[i].theme_type_variation = &"PrimaryButton" if selected else &""
	var definition := DrillRegistry.find(MetricCatalog.drill_id_of(variant))
	_detail_title.text = tr(definition.title_key) if definition != null else variant
	var label := MetricCatalog.variant_label(variant)
	_detail_variant.text = tr("PROGRESS_DEFAULT_VARIANT") if label.is_empty() else label
	for child in _rows.get_children():
		child.queue_free()
	var overview := StatsStore.history.overview(variant)
	if overview.is_empty():
		_sparkline.values = PackedFloat64Array()
		return
	var unit: String = overview["unit"]
	var lower: bool = overview["lower"]
	var runs: int = overview["runs"]
	var last: float = overview["last"]
	var best: float = overview["best"]
	var recent_mean: float = overview["recent_mean"]
	_add_row("PROGRESS_RUNS", str(runs))
	_add_row("PROGRESS_LAST", MetricCatalog.format_value(last, unit))
	_add_row("PROGRESS_BEST", MetricCatalog.format_value(best, unit))
	if runs >= 2:
		_add_row("PROGRESS_RECENT_MEAN", MetricCatalog.format_value(recent_mean, unit))
	var change: float = overview["change"]
	if not is_nan(change):
		var improved := change < 0.0 if lower else change > 0.0
		var word := tr("RESULT_BETTER") if improved else tr("RESULT_WORSE")
		_add_row("PROGRESS_CHANGE", "%s (%s)" % [MetricCatalog.format_delta(change, unit), word] if change != 0.0 else MetricCatalog.format_delta(0.0, unit))
	var level: int = overview["last_level"]
	if level >= 0:
		_add_row("PROGRESS_LEVEL", tr(Benchmarks.LEVEL_KEYS[level]))
	var last_runs := StatsStore.history.for_variant(variant)
	var last_rpe: int = last_runs[last_runs.size() - 1]["rpe"]
	if last_rpe > 0:
		_add_row("PROGRESS_LAST_RPE", "%d / 10" % last_rpe)
	_sparkline.lower_is_better = lower
	_sparkline.unit = unit
	_sparkline.dates = overview["dates"]
	_sparkline.values = overview["values"]


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
