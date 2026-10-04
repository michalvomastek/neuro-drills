## Digit span: remember the digits shown one at a time, then type them back.
extends TrialDrill

const SHOW_SECONDS := 0.9
const GAP_SECONDS := 0.25
const FEEDBACK_SECONDS := 1.0
const KEYPAD: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK"]

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
	_keypad = GridContainer.new()
	_keypad.columns = 3
	_keypad.add_theme_constant_override("h_separation", 10)
	_keypad.add_theme_constant_override("v_separation", 10)
	center.add_child(_keypad)
	for key in KEYPAD:
		var button := _make_pad(key, 32)
		button.custom_minimum_size = Vector2(110, 64)
		button.size_flags_horizontal = Control.SIZE_FILL
		button.size_flags_vertical = Control.SIZE_FILL
		button.pressed.connect(_on_key.bind(key))
		_keypad.add_child(button)
	_keypad.visible = false


func _handle_response(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code := key.keycode
	if code >= KEY_0 and code <= KEY_9:
		_on_key(str(code - KEY_0))
	elif code >= KEY_KP_0 and code <= KEY_KP_9:
		_on_key(str(code - KEY_KP_0))
	elif code == KEY_BACKSPACE:
		_on_key("⌫")
	elif code == KEY_ENTER or code == KEY_KP_ENTER:
		_on_key("OK")
	else:
		return
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
	if key == "⌫":
		if not _answer.is_empty():
			_answer.pop_back()
	elif key == "OK":
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
