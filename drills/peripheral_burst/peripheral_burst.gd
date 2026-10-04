## Peripheral burst: stare at the centre digit, press space or click whenever a
## flash appears around it, and count how often the digit changed.
extends TrialDrill

var _logic: PeripheralLogic
var _pad: Button
var _stage: Control
var _centre: Label
var _flash: Panel
var _flash_style: StyleBoxFlat
var _question: VBoxContainer
var _question_label: Label
var _answer: String = ""
var _keypad: GridContainer
var _window_open: bool = false
var _stimulus_ms: int = 0
var _asking: bool = false
var _centre_digit: int = 5


func _trial_options() -> Array[int]:
	return [15, 25, 40]


func _default_trials() -> int:
	return 15


func _build_play_area(parent: Control) -> void:
	_pad = _make_pad()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.pressed.connect(_on_response)
	parent.add_child(_pad)
	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_stage)
	_centre = Label.new()
	_centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_centre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_centre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_centre.add_theme_font_size_override("font_size", 40)
	_centre.size = Vector2(80, 80)
	_stage.add_child(_centre)
	_flash = Panel.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.size = Vector2(44, 44)
	_flash_style = StyleBoxFlat.new()
	_flash_style.set_corner_radius_all(22)
	_flash_style.bg_color = get_theme_color("lit", "Board")
	_flash.add_theme_stylebox_override("panel", _flash_style)
	_flash.visible = false
	_stage.add_child(_flash)
	_stage.resized.connect(_layout)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	_question = VBoxContainer.new()
	_question.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_question.add_theme_constant_override("separation", 16)
	center.add_child(_question)
	_question_label = Label.new()
	_question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question_label.add_theme_font_size_override("font_size", 32)
	_question.add_child(_question_label)
	_keypad = _make_keypad(_question, _on_key)
	_question.visible = false


func _layout() -> void:
	_centre.position = _stage.size * 0.5 - _centre.size * 0.5


func _handle_response(event: InputEvent) -> void:
	if _asking:
		var label := _keypad_label_from_event(event)
		if not label.is_empty():
			_on_key(label)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_on_response()
		get_viewport().set_input_as_handled()


func _reset_play_state() -> void:
	_window_open = false
	_asking = false
	if _flash != null:
		_flash.visible = false


func _run_trials() -> void:
	_logic = PeripheralLogic.new(trials, _rng)
	_asking = false
	_question.visible = false
	_pad.visible = true
	_centre.text = str(_centre_digit)
	_layout()
	if not await _wait(1.0):
		return
	for i in trials:
		if not await _wait(_logic.next_gap_ms() / 1000.0):
			return
		if _logic.centre_changes[i]:
			_centre_digit = _logic.next_centre_digit(_centre_digit)
			_centre.text = str(_centre_digit)
			if not await _wait(0.25):
				return
		var side := minf(_stage.size.x, _stage.size.y)
		_flash.position = _stage.size * 0.5 + _logic.offsets[i] * side - _flash.size * 0.5
		_flash.visible = true
		_window_open = true
		_stimulus_ms = Time.get_ticks_msec()
		if not await _wait(PeripheralLogic.FLASH_MS / 1000.0):
			return
		_flash.visible = false
		if not await _wait((PeripheralLogic.RESPONSE_WINDOW_MS - PeripheralLogic.FLASH_MS) / 1000.0):
			return
		_window_open = false
		_logic.close_window()
		_set_progress(i + 1)
	_ask_centre_count()


func _on_response() -> void:
	if not _running or not _window_open:
		return
	if _logic.respond(Time.get_ticks_msec() - _stimulus_ms):
		_flash_pad(_pad, get_theme_color("correct", "Pad"), 0.25)


func _ask_centre_count() -> void:
	_asking = true
	_answer = ""
	_pad.visible = false
	_centre.text = ""
	_question_label.text = tr("PERIPHERAL_QUESTION")
	_question.visible = true


func _on_key(key: String) -> void:
	if not _running or not _asking:
		return
	if key == KEY_BACKSPACE_LABEL:
		_answer = _answer.left(-1)
	elif key == KEY_OK_LABEL:
		if not _answer.is_empty():
			_asking = false
			_logic.report_centre_changes(int(_answer))
			_complete(_logic.build_result(definition.id, get_config()))
		return
	elif _answer.length() < 2:
		_answer += key
	_question_label.text = tr("PERIPHERAL_QUESTION") + ("\n" + _answer if not _answer.is_empty() else "")
