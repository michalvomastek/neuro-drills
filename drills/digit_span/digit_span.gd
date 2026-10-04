## Digit span: remember the digits shown one at a time, then type them back.
extends TrialDrill

const SHOW_SECONDS := 0.9
const GAP_SECONDS := 0.25
const FEEDBACK_SECONDS := 1.0

var _backward: bool = false
var _backward_check: CheckBox
var _logic: DigitSpanLogic
var _display: Label
var _keypad: GridContainer
var _answer: Array[int] = []
var _accepting: bool = false


func _uses_trial_count() -> bool:
	return false


func _build_extras(parent: VBoxContainer) -> void:
	_backward_check = CheckBox.new()
	_backward_check.text = tr("DIGIT_OPT_BACKWARD")
	parent.add_child(_backward_check)


func _apply_extra_config(config: Dictionary) -> void:
	_backward = config.get("backward", false)
	_backward_check.button_pressed = _backward


func _collect_extra_config() -> Dictionary:
	return {"backward": _backward}


func _on_start_pressed() -> void:
	_backward = _backward_check.button_pressed
	super()


func _build_play_area(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	parent.add_child(vbox)
	var display_area := Control.new()
	display_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(display_area)
	_display = _make_stimulus_label(display_area, 120)
	var center := CenterContainer.new()
	vbox.add_child(center)
	_keypad = _make_keypad(center, _on_key)
	_keypad.visible = false


func _handle_response(event: InputEvent) -> void:
	var label := _keypad_label_from_event(event)
	if label.is_empty():
		return
	_on_key(label)
	get_viewport().set_input_as_handled()


func _run_trials() -> void:
	_logic = DigitSpanLogic.new(_backward, _rng)
	_play_round()


func _play_round() -> void:
	_accepting = false
	_keypad.visible = false
	_answer.clear()
	_display.text = ""
	_display.remove_theme_color_override("font_color")
	_display.add_theme_font_size_override("font_size", 120)
	_set_progress_text(tr("SPAN_LENGTH") % _logic.tracker.length)
	var sequence := _logic.new_sequence()
	if not await _wait(0.8):
		return
	for digit in sequence:
		_display.text = str(digit)
		if not await _wait(SHOW_SECONDS):
			return
		_display.text = ""
		if not await _wait(GAP_SECONDS):
			return
	_display.text = tr("DIGIT_PROMPT_BACKWARD") if _backward else tr("DIGIT_PROMPT_FORWARD")
	_display.add_theme_color_override("font_color", get_theme_color("font_color", "DimLabel"))
	_display.add_theme_font_size_override("font_size", 40)
	_keypad.visible = true
	_accepting = true


func _on_key(key: String) -> void:
	if not _running or not _accepting:
		return
	if key == KEY_BACKSPACE_LABEL:
		if not _answer.is_empty():
			_answer.pop_back()
	elif key == KEY_OK_LABEL:
		if not _answer.is_empty():
			_submit()
		return
	elif _answer.size() < _logic.sequence.size():
		_answer.append(int(key))
	_show_answer()


func _show_answer() -> void:
	_display.remove_theme_color_override("font_color")
	_display.add_theme_font_size_override("font_size", 96)
	var text := ""
	for digit in _answer:
		text += str(digit) + " "
	_display.text = text.strip_edges()


func _submit() -> void:
	_accepting = false
	_keypad.visible = false
	var success := _logic.check(_answer.duplicate())
	_display.add_theme_color_override("font_color", get_theme_color("correct" if success else "wrong", "Pad"))
	if not success:
		var text := ""
		for digit in _logic.expected():
			text += str(digit) + " "
		_display.text = text.strip_edges()
	if not await _wait(FEEDBACK_SECONDS):
		return
	if _logic.tracker.done:
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_play_round()
