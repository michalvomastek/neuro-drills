## Composes a training: length slider, suggested or saved steps, editing
## and start. Steps are {"drill_id", "config"} as TrainingPlan makes them.
class_name TrainingScreen
extends Control

@onready var _margin: MarginContainer = %Margin
@onready var _back_button: Button = %BackButton
@onready var _minutes_slider: HSlider = %MinutesSlider
@onready var _minutes_label: Label = %MinutesLabel
@onready var _plans_row: BoxContainer = %PlansRow
@onready var _plans_option: OptionButton = %PlansOption
@onready var _load_button: Button = %LoadButton
@onready var _delete_button: Button = %DeleteButton
@onready var _step_list: VBoxContainer = %StepList
@onready var _empty_label: Label = %EmptyLabel
@onready var _add_row: BoxContainer = %AddRow
@onready var _drill_option: OptionButton = %DrillOption
@onready var _add_button: Button = %AddButton
@onready var _suggest_button: Button = %SuggestButton
@onready var _save_button: Button = %SaveButton
@onready var _footer: GridContainer = %Footer
@onready var _estimate_label: Label = %EstimateLabel
@onready var _start_button: Button = %StartButton

var _steps: Array[Dictionary] = []
var _plan_name: String = ""
## True once the player loaded or edited the list, so a new length keeps it.
var _custom: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_back_button.pressed.connect(SceneRouter.show_menu)
	_minutes_slider.min_value = TrainingPlan.MIN_MINUTES
	_minutes_slider.max_value = TrainingPlan.MAX_MINUTES
	_minutes_slider.value = StatsStore.training_minutes
	_minutes_slider.value_changed.connect(_on_minutes_changed)
	_load_button.pressed.connect(_on_load_pressed)
	_delete_button.pressed.connect(_on_delete_pressed)
	_add_button.pressed.connect(_on_add_pressed)
	_suggest_button.pressed.connect(_suggest)
	_save_button.pressed.connect(_on_save_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	for definition in DrillRegistry.get_all():
		_drill_option.add_item(tr(definition.title_key))
		_drill_option.set_item_metadata(_drill_option.item_count - 1, String(definition.id))
	_refresh_plans()
	_update_minutes_label()
	Layout.watch(self, _relayout)
	_suggest()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneRouter.show_menu()
		get_viewport().set_input_as_handled()


func _relayout() -> void:
	var narrow := Layout.is_narrow(self)
	Layout.set_margins(_margin, Layout.side_margin(self), 12 if narrow else 32)
	_plans_row.vertical = narrow
	_add_row.vertical = false
	_footer.columns = 2 if narrow else 4
	for button: Button in [_suggest_button, _save_button, _start_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_FILL


func _minutes() -> int:
	return int(_minutes_slider.value)


## A new length re-suggests only while the list is still the app's own
## suggestion; a loaded or edited plan is kept.
func _on_minutes_changed(_value: float) -> void:
	StatsStore.set_training_minutes(_minutes())
	_update_minutes_label()
	if not _custom:
		_suggest()


func _update_minutes_label() -> void:
	_minutes_label.text = tr("TRAINING_MINUTES_VALUE") % _minutes()


## New proposal from the weakest categories for the chosen length.
func _suggest() -> void:
	var definitions := DrillRegistry.get_all()
	var now := int(Time.get_unix_time_from_system())
	var order := TrainingPlan.weak_categories(definitions, StatsStore.history, DrillRegistry.CATEGORY_ORDER, now)
	var harder := TrainingPlan.harder_configs(StatsStore.history)
	_steps = TrainingPlan.suggest(definitions, _minutes(), order, _rng, harder)
	_plan_name = ""
	_custom = false
	_rebuild_steps()


func _rebuild_steps() -> void:
	for child in _step_list.get_children():
		child.queue_free()
	_empty_label.visible = _steps.is_empty()
	for i in _steps.size():
		_step_list.add_child(_make_step_row(i))
	var seconds := TrainingPlan.total_seconds(_steps)
	_estimate_label.text = tr("TRAINING_ESTIMATE") % [Format.minutes_seconds(seconds), _steps.size()]
	_start_button.disabled = _steps.is_empty()
	_save_button.disabled = _steps.is_empty()


func _make_step_row(index: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var number := Label.new()
	number.text = "%d." % (index + 1)
	number.theme_type_variation = &"DimLabel"
	number.custom_minimum_size = Vector2(32, 0)
	row.add_child(number)
	var step := _steps[index]
	var drill_id: String = step["drill_id"]
	var definition := DrillRegistry.find(StringName(drill_id))
	var title := Label.new()
	title.text = tr(definition.title_key) if definition != null else drill_id
	var config: Dictionary = step["config"]
	var label := MetricCatalog.variant_label(MetricCatalog.variant_key(StringName(drill_id), config))
	if not label.is_empty():
		title.text += " · " + label
	if step.get("harder", false):
		title.text += " " + tr("TRAINING_HARDER")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(title)
	var duration := Label.new()
	duration.text = tr("TRAINING_STEP_TIME") % TrainingPlan.estimate_seconds(StringName(drill_id))
	duration.theme_type_variation = &"DimLabel"
	row.add_child(duration)
	var up := Button.new()
	up.text = "▲"
	up.flat = true
	up.disabled = index == 0
	up.pressed.connect(_move_step.bind(index, -1))
	row.add_child(up)
	var down := Button.new()
	down.text = "▼"
	down.flat = true
	down.disabled = index == _steps.size() - 1
	down.pressed.connect(_move_step.bind(index, 1))
	row.add_child(down)
	var remove := Button.new()
	remove.text = "✕"
	remove.flat = true
	remove.tooltip_text = tr("TRAINING_REMOVE")
	remove.pressed.connect(_remove_step.bind(index))
	row.add_child(remove)
	return row


func _move_step(index: int, delta: int) -> void:
	var target := index + delta
	if target < 0 or target >= _steps.size():
		return
	_custom = true
	var step := _steps[index]
	_steps.remove_at(index)
	_steps.insert(target, step)
	_rebuild_steps()


func _remove_step(index: int) -> void:
	_custom = true
	_steps.remove_at(index)
	_rebuild_steps()


func _on_add_pressed() -> void:
	if _drill_option.selected < 0:
		return
	var drill_id: String = _drill_option.get_item_metadata(_drill_option.selected)
	_steps.append(TrainingPlan.make_step(StringName(drill_id)))
	_custom = true
	_rebuild_steps()


func _refresh_plans() -> void:
	_plans_option.clear()
	for plan in StatsStore.plans:
		var plan_name: String = plan["name"]
		_plans_option.add_item(plan_name)
	var has_plans := _plans_option.item_count > 0
	_plans_row.visible = has_plans
	_load_button.disabled = not has_plans
	_delete_button.disabled = not has_plans


func _selected_plan_name() -> String:
	if _plans_option.selected < 0:
		return ""
	return _plans_option.get_item_text(_plans_option.selected)


func _on_load_pressed() -> void:
	var plan := StatsStore.find_plan(_selected_plan_name())
	if plan.is_empty():
		return
	var steps: Array[Dictionary] = plan["steps"]
	_steps = steps.duplicate(true)
	_plan_name = plan["name"]
	_custom = true
	_rebuild_steps()


func _on_delete_pressed() -> void:
	StatsStore.delete_plan(_selected_plan_name())
	_refresh_plans()


func _on_save_pressed() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = tr("TRAINING_SAVE")
	dialog.ok_button_text = tr("FEEDBACK_SAVE")
	dialog.cancel_button_text = tr("COMMON_BACK")
	var edit := LineEdit.new()
	edit.placeholder_text = tr("TRAINING_PLAN_NAME")
	edit.text = _plan_name if not _plan_name.is_empty() else "%s %d min" % [tr("TRAINING_TITLE"), _minutes()]
	edit.custom_minimum_size = Vector2(minf(360.0, Layout.viewport_width(self) - 80.0), 0)
	dialog.add_child(edit)
	dialog.register_text_enter(edit)
	dialog.confirmed.connect(func() -> void:
		var plan_name := edit.text.strip_edges()
		if plan_name.is_empty():
			return
		StatsStore.save_plan(plan_name, _steps)
		_plan_name = plan_name
		_refresh_plans()
		_plans_option.select(_plans_option.item_count - 1))
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()
	edit.grab_focus()
	edit.select_all()


func _on_start_pressed() -> void:
	if _steps.is_empty():
		return
	SceneRouter.start_training(TrainingSession.new(_steps, _plan_name))

