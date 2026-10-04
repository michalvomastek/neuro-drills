## Flashing number: look at the centre dot, catch the number that flashes
## somewhere around it and type it.
extends TrialDrill

const FEEDBACK_SECONDS := 1.0

var _logic: FlashLogic
var _stage: Control
var _dot: Label
var _number: Label
var _prompt: Label
var _keypad: GridContainer
var _answer: String = ""
var _accepting: bool = false


func _uses_trial_count() -> bool:
	return false


func _build_play_area(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	parent.add_child(vbox)
	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_stage)
	_dot = Label.new()
	_dot.text = "•"
	_dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dot.add_theme_font_size_override("font_size", 44)
	_dot.size = Vector2(60, 60)
	_stage.add_child(_dot)
	_number = Label.new()
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number.add_theme_font_size_override("font_size", 64)
	_number.size = Vector2(400, 100)
	_stage.add_child(_number)
	_prompt = Label.new()
	_prompt.theme_type_variation = &"DimLabel"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 32)
	vbox.add_child(_prompt)
	var center := CenterContainer.new()
	vbox.add_child(center)
	_keypad = _make_keypad(center, _on_key)
	_keypad.visible = false
	_stage.resized.connect(_layout)


func _layout() -> void:
	var center := _stage.size * 0.5
	_dot.position = center - _dot.size * 0.5
	var offset := _logic.offset if _logic != null else Vector2.ZERO
	_number.position = center + offset * _stage.size - _number.size * 0.5


func _handle_response(event: InputEvent) -> void:
	var label := _keypad_label_from_event(event)
	if label.is_empty():
		return
	_on_key(label)
	get_viewport().set_input_as_handled()


func _run_trials() -> void:
	_logic = FlashLogic.new(_rng)
	_play_round()


func _play_round() -> void:
	_accepting = false
	_keypad.visible = false
	_answer = ""
	_number.text = ""
	_number.remove_theme_color_override("font_color")
	_prompt.text = ""
	_set_progress_text(tr("FLASH_LENGTH") % _logic.tracker.length)
	if not await _wait(1.0):
		return
	_number.text = _logic.new_round()
	_layout()
	if not await _wait(FlashLogic.FLASH_MS / 1000.0):
		return
	_number.text = ""
	_prompt.text = tr("FLASH_PROMPT")
	_keypad.visible = true
	_accepting = true


func _on_key(key: String) -> void:
	if not _running or not _accepting:
		return
	if key == KEY_BACKSPACE_LABEL:
		_answer = _answer.left(-1)
	elif key == KEY_OK_LABEL:
		if not _answer.is_empty():
			_submit()
		return
	elif _answer.length() < _logic.number.length():
		_answer += key
	_prompt.text = _answer if not _answer.is_empty() else tr("FLASH_PROMPT")


func _submit() -> void:
	_accepting = false
	_keypad.visible = false
	var correct := _logic.check(_answer)
	_number.text = _logic.number
	_number.add_theme_color_override("font_color", get_theme_color("correct" if correct else "wrong", "Pad"))
	if not await _wait(FEEDBACK_SECONDS):
		return
	if _logic.tracker.done:
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_play_round()
