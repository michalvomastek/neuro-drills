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
@onready var _status_label: Label = %StatusLabel
@onready var _export_button: Button = %ExportButton
@onready var _clear_button: Button = %ClearButton
@onready var _clear_dialog: ConfirmationDialog = %ClearDialog
@onready var _margin: MarginContainer = %Margin
@onready var _body: BoxContainer = %Body
@onready var _list_scroll: ScrollContainer = %ListScroll
@onready var _footer_spacer: Control = %FooterSpacer
@onready var _variant_option: ListPickButton = %VariantOption
@onready var _week_label: Label = %WeekLabel
@onready var _chart_label: Label = %ChartLabel
@onready var _range_buttons: HBoxContainer = %RangeButtons
@onready var _backup_button: Button = %BackupButton
@onready var _import_button: Button = %ImportButton
@onready var _import_dialog: FileDialog = %ImportDialog

## Chart ranges in runs; 0 means every run.
const CHART_RANGES: Array[int] = [20, 50, 0]

var _buttons: Array[Button] = []
var _range_toggles: Array[Button] = []
var _chart_runs: int = StatsHistory.SPARKLINE_RUNS
var _variant: String = ""
## Keeps the web import callback alive while the picker is open.
var _web_import_callback: JavaScriptObject


func _ready() -> void:
	_variant_option.item_selected.connect(func(index: int) -> void: _select(StatsStore.history.variants()[index]))
	_export_button.pressed.connect(_on_export_pressed)
	_backup_button.pressed.connect(_on_backup_pressed)
	_import_button.pressed.connect(_on_import_pressed)
	_import_dialog.file_selected.connect(_on_import_file_selected)
	_build_range_buttons()
	_clear_button.pressed.connect(_on_clear_pressed)
	_clear_dialog.confirmed.connect(_on_clear_confirmed)
	_clear_dialog.ok_button_text = tr("PROGRESS_CLEAR_VARIANT")
	_clear_dialog.cancel_button_text = tr("COMMON_BACK")
	Layout.watch(self, _relayout)
	_populate()


## Fills the week line and the variant list from the store; runs again after an import.
func _populate() -> void:
	for button in _buttons:
		_list.remove_child(button)
		button.queue_free()
	_buttons.clear()
	var week := StatsStore.history.week_summary(int(Time.get_unix_time_from_system()))
	var week_runs: int = week["runs"]
	_week_label.visible = week_runs > 0
	_week_label.text = tr("PROGRESS_WEEK") % [week_runs, week["minutes"], week["drills"], week["improved"]]
	var variants := StatsStore.history.variants()
	_empty_label.visible = variants.is_empty()
	_detail.visible = not variants.is_empty()
	_export_button.disabled = variants.is_empty()
	_backup_button.disabled = variants.is_empty()
	_clear_button.disabled = variants.is_empty()
	_variant_option.clear()
	for variant in variants:
		_add_variant_button(variant)
		_variant_option.add_item(_variant_title(variant))
	if not _buttons.is_empty():
		_select(variants[0])
		_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneRouter.show_menu()
		get_viewport().set_input_as_handled()


## On a phone the variant list sits above the detail instead of beside it.
func _relayout() -> void:
	var narrow := Layout.is_narrow(self)
	Layout.set_screen_margins(_margin)
	_body.vertical = narrow
	# A phone picks the variant from a dropdown (the whole screen scrolls, so
	# a nested scrolling list would fight the finger); a wide screen lists them.
	_list_scroll.visible = not narrow
	_variant_option.visible = narrow
	_detail.custom_minimum_size = Vector2(0, 0) if narrow else Vector2(320, 0)
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_footer_spacer.visible = not narrow


func _on_export_pressed() -> void:
	var path := StatsStore.export_csv()
	_status_label.text = tr("PROGRESS_EXPORTED") % path if not path.is_empty() else tr("PROGRESS_EXPORT_FAILED")
	_status_label.tooltip_text = path


func _on_backup_pressed() -> void:
	var path := StatsStore.export_backup()
	_status_label.text = tr("PROGRESS_EXPORTED") % path if not path.is_empty() else tr("PROGRESS_EXPORT_FAILED")
	_status_label.tooltip_text = path


## Desktop: a file dialog. Web: an <input type=file> element, read in the
## browser and handed back as text through a JavaScript callback.
func _on_import_pressed() -> void:
	if OS.has_feature("web"):
		_web_import_callback = JavaScriptBridge.create_callback(_on_web_import)
		var window := JavaScriptBridge.get_interface("window")
		window.set("neuroDrillsImport", _web_import_callback)
		JavaScriptBridge.eval("(function(){var i=document.createElement('input');i.type='file';i.accept='.jsonl,.txt,.json';i.onchange=function(){var f=i.files[0];if(!f){return;}var r=new FileReader();r.onload=function(){window.neuroDrillsImport(r.result);};r.readAsText(f);};i.click();})();", true)
		return
	_import_dialog.popup_centered_ratio(0.8)


func _on_web_import(args: Array) -> void:
	if args.is_empty():
		return
	_apply_import(str(args[0]))


func _on_import_file_selected(path: String) -> void:
	_apply_import(FileAccess.get_file_as_string(path))


func _apply_import(text: String) -> void:
	var added := StatsStore.import_backup(text)
	if added < 0:
		_status_label.text = tr("PROGRESS_IMPORT_NOTHING")
		return
	_populate()
	_status_label.text = tr("PROGRESS_IMPORTED") % added


## 20 / 50 / all runs for the chart.
func _build_range_buttons() -> void:
	for runs in CHART_RANGES:
		var button := Button.new()
		button.text = str(runs) if runs > 0 else tr("PROGRESS_RANGE_ALL")
		button.toggle_mode = true
		button.pressed.connect(_on_range_pressed.bind(runs))
		_range_buttons.add_child(button)
		_range_toggles.append(button)
	_update_range_buttons()


func _update_range_buttons() -> void:
	for i in _range_toggles.size():
		var selected := CHART_RANGES[i] == _chart_runs
		_range_toggles[i].button_pressed = selected
		_range_toggles[i].theme_type_variation = &"SmallPrimaryButton" if selected else &"SmallButton"
	_chart_label.text = tr("PROGRESS_CHART_N") % _chart_runs if _chart_runs > 0 else tr("PROGRESS_CHART_ALL")


func _on_range_pressed(runs: int) -> void:
	_chart_runs = runs
	_update_range_buttons()
	if not _variant.is_empty():
		_select(_variant)


## Deleting here is per variant: the whole history goes only from Settings.
func _on_clear_pressed() -> void:
	if _variant.is_empty():
		return
	_clear_dialog.dialog_text = tr("PROGRESS_CLEAR_VARIANT_CONFIRM") % _variant_title(_variant)
	_clear_dialog.popup_centered()


func _on_clear_confirmed() -> void:
	if _variant.is_empty():
		return
	StatsStore.clear_variant(_variant)
	_variant = ""
	_populate()


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
	_variant = variant
	var variants := StatsStore.history.variants()
	for i in _buttons.size():
		var selected := variants[i] == variant
		_buttons[i].button_pressed = selected
		_buttons[i].theme_type_variation = &"PrimaryButton" if selected else &""
		if selected and _variant_option.selected != i:
			_variant_option.select(i)
	var definition := DrillRegistry.find(MetricCatalog.drill_id_of(variant))
	_detail_title.text = tr(definition.title_key) if definition != null else variant
	var label := MetricCatalog.variant_label(variant)
	_detail_variant.text = tr("PROGRESS_DEFAULT_VARIANT") if label.is_empty() else label
	for child in _rows.get_children():
		child.queue_free()
	var overview := StatsStore.history.overview(variant, StatsHistory.TREND_WINDOW, _chart_runs)
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
	if MetricCatalog.THRESHOLD_DRILLS.has(String(MetricCatalog.drill_id_of(variant))):
		var stable := StatsStore.history.stable_best(variant, int(Time.get_unix_time_from_system()))
		if not is_nan(stable):
			_add_row("PROGRESS_STABLE_BEST", MetricCatalog.format_value(stable, unit))
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
	var config: Dictionary = overview["config"]
	var metric: String = StatsStore.history.for_variant(variant)[0]["metric"]
	var bounds := Benchmarks.bounds_for(MetricCatalog.drill_id_of(variant), config, metric)
	_sparkline.bands = {"advanced": bounds["advanced"], "elite": bounds["elite"]} if not bounds.is_empty() else {}
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
