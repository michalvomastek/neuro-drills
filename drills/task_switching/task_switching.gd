## Task switching: the frame colour tells which rule applies to the digit.
extends TrialDrill

const FEEDBACK_SECONDS := 0.4
const GAP_SECONDS := 0.5

var _logic: SwitchLogic
var _pads: Array[Button] = []
var _frame: PanelContainer
var _frame_style: StyleBoxFlat
var _digit: Label
var _rule_label: Label
var _hint_left: Label
var _hint_right: Label
var _awaiting_response: bool = false
var _stimulus_ms: int = 0


func _trial_options() -> Array[int]:
	return [24, 48, 72]


func _default_trials() -> int:
	return 24


func _build_play_area(parent: Control) -> void:
	_pads = _make_side_pads(parent)
	for side in _pads.size():
		_pads[side].text = ""
		_pads[side].pressed.connect(_on_side_pressed.bind(side))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	_rule_label = Label.new()
	_rule_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rule_label.add_theme_font_size_override("font_size", 28)
	column.add_child(_rule_label)
	_frame = PanelContainer.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_style = StyleBoxFlat.new()
	_frame_style.set_corner_radius_all(16)
	_frame_style.set_border_width_all(10)
	_frame_style.set_content_margin_all(24)
	_frame_style.bg_color = get_theme_color("cell", "Board")
	_frame.add_theme_stylebox_override("panel", _frame_style)
	column.add_child(_frame)
	_digit = Label.new()
	_digit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_digit.custom_minimum_size = Vector2(200, 200)
	_digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_digit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_digit.add_theme_font_size_override("font_size", 140)
	_frame.add_child(_digit)
	var hints := HBoxContainer.new()
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints.add_theme_constant_override("separation", 80)
	column.add_child(hints)
	_hint_left = Label.new()
	_hint_left.theme_type_variation = &"DimLabel"
	_hint_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints.add_child(_hint_left)
	_hint_right = Label.new()
	_hint_right.theme_type_variation = &"DimLabel"
	_hint_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints.add_child(_hint_right)
	_frame.visible = false


func _handle_response(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_on_side_pressed(0)
	elif event.is_action_pressed("ui_right"):
		_on_side_pressed(1)
	else:
		return
	get_viewport().set_input_as_handled()


func _run_trials() -> void:
	_logic = SwitchLogic.new(trials, _rng)
	_next_trial()


func _next_trial() -> void:
	_awaiting_response = false
	_frame.visible = false
	_rule_label.text = ""
	_hint_left.text = ""
	_hint_right.text = ""
	if not await _wait(GAP_SECONDS):
		return
	var parity := _logic.current_task() == SwitchLogic.Task.PARITY
	_frame_style.border_color = get_theme_color("task_parity" if parity else "task_magnitude", "Board")
	_rule_label.text = tr("SWITCH_RULE_PARITY") if parity else tr("SWITCH_RULE_MAGNITUDE")
	_rule_label.add_theme_color_override("font_color", _frame_style.border_color)
	_hint_left.text = "◀ " + (tr("SWITCH_ODD") if parity else tr("SWITCH_LESS"))
	_hint_right.text = (tr("SWITCH_EVEN") if parity else tr("SWITCH_MORE")) + " ▶"
	_digit.text = str(_logic.current_digit())
	_frame.visible = true
	_stimulus_ms = Time.get_ticks_msec()
	_awaiting_response = true


func _on_side_pressed(side: int) -> void:
	if not _running or not _awaiting_response:
		return
	_awaiting_response = false
	var correct := _logic.record_response(side, Time.get_ticks_msec() - _stimulus_ms)
	_flash_pad(_pads[side], get_theme_color("correct" if correct else "wrong", "Pad"), FEEDBACK_SECONDS)
	_set_progress(_logic.current)
	if not await _wait(FEEDBACK_SECONDS):
		return
	if _logic.is_done():
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_next_trial()
