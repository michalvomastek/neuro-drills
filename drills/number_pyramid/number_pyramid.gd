## Number pyramid: keep your eyes on the centre dot; two digits flash on the
## sides, then type them left to right.
extends TrialDrill

const FEEDBACK_SECONDS := 0.8

var _logic: PyramidLogic
var _stage: Control
var _dot: Label
var _left: Label
var _right: Label
var _prompt: Label
var _keypad: GridContainer
var _answer: Array[int] = []
var _accepting: bool = false


func _trial_options() -> Array[int]:
	return [10, 15, 20]


func _default_trials() -> int:
	return 10


func _build_play_area(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	parent.add_child(vbox)
	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_stage)
	_dot = _make_side_label(44)
	_dot.text = "•"
	_left = _make_side_label(96)
	_right = _make_side_label(96)
	_prompt = Label.new()
	_prompt.theme_type_variation = &"DimLabel"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_prompt)
	var center := CenterContainer.new()
	vbox.add_child(center)
	_keypad = _make_keypad(center, _on_key)
	_keypad.visible = false
	_stage.resized.connect(_layout)


func _make_side_label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.size = Vector2(120, 120)
	_stage.add_child(label)
	return label


func _layout() -> void:
	var center := _stage.size * 0.5
	var offset := Vector2(_stage.size.x * (_logic.distance if _logic != null else PyramidLogic.START_DISTANCE), 0)
	_dot.position = center - _dot.size * 0.5
	_left.position = center - offset - _left.size * 0.5
	_right.position = center + offset - _right.size * 0.5


func _handle_response(event: InputEvent) -> void:
	var label := _keypad_label_from_event(event)
	if label.is_empty():
		return
	_on_key(label)
	get_viewport().set_input_as_handled()


func _run_trials() -> void:
	_logic = PyramidLogic.new(trials, _rng)
	_play_round()


func _play_round() -> void:
	_accepting = false
	_keypad.visible = false
	_answer.clear()
	_left.text = ""
	_right.text = ""
	_prompt.text = ""
	_layout()
	_set_progress_text("%s %d %%   %d / %d" % [tr("PYRAMID_SPAN"), roundi(_logic.distance * 200.0), _logic.rounds_done, trials])
	if not await _wait(1.0):
		return
	_logic.new_round()
	_left.text = str(_logic.left)
	_right.text = str(_logic.right)
	if not await _wait(PyramidLogic.FLASH_MS / 1000.0):
		return
	_left.text = ""
	_right.text = ""
	_prompt.text = tr("PYRAMID_PROMPT")
	_keypad.visible = true
	_accepting = true


func _on_key(key: String) -> void:
	if not _running or not _accepting:
		return
	if key == KEY_BACKSPACE_LABEL:
		if not _answer.is_empty():
			_answer.pop_back()
	elif key == KEY_OK_LABEL:
		return
	elif _answer.size() < 2:
		_answer.append(int(key))
	_prompt.text = " ".join(_answer.map(func(d: int) -> String: return str(d))) if not _answer.is_empty() else tr("PYRAMID_PROMPT")
	if _answer.size() == 2:
		_submit()


func _submit() -> void:
	_accepting = false
	_keypad.visible = false
	var correct := _logic.check(_answer[0], _answer[1])
	_left.text = str(_logic.left)
	_right.text = str(_logic.right)
	var color := get_theme_color("correct" if correct else "wrong", "Pad")
	_left.add_theme_color_override("font_color", color)
	_right.add_theme_color_override("font_color", color)
	if not await _wait(FEEDBACK_SECONDS):
		return
	_left.remove_theme_color_override("font_color")
	_right.remove_theme_color_override("font_color")
	if _logic.is_done():
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_play_round()
