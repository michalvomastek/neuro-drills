## Peripheral pattern search: keep looking at the centre digit; patterns flash
## in eight sectors around it. Press the number of the sector holding three
## blue bars (keyboard or the row of buttons below the stage, so it works on
## a phone too). At the end, count the centre changes.
extends TrialDrill

const RADIUS := 0.4
const BAR_SIZE := Vector2(10, 46)

var _logic: PatternLogic
var _stage: Control
var _centre: Label
var _sector_boxes: Array[HBoxContainer] = []
var _sector_labels: Array[Label] = []
var _question: VBoxContainer
var _question_label: Label
var _answer_label: Label
var _keypad: GridContainer
var _answer: String = ""
var _centre_digit: int = 5
var _accepting: bool = false
var _asking: bool = false
var _sector_buttons: Array[Button] = []


func _trial_options() -> Array[int]:
	return [10, 16, 24]


func _default_trials() -> int:
	return 10


func _build_play_area(parent: Control) -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_stage)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	for i in PatternLogic.SECTORS:
		var button := Button.new()
		button.text = str(i + 1)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(48, 0)
		Drill.make_press_button(button)
		button.pressed.connect(_on_sector.bind(i))
		row.add_child(button)
		_sector_buttons.append(button)
	_centre = Label.new()
	_centre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_centre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_centre.add_theme_font_size_override("font_size", 44)
	_centre.size = Vector2(80, 80)
	_stage.add_child(_centre)
	for i in PatternLogic.SECTORS:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.visible = false
		_stage.add_child(box)
		_sector_boxes.append(box)
		var number := Label.new()
		number.text = str(i + 1)
		number.theme_type_variation = &"DimLabel"
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.size = Vector2(40, 30)
		_stage.add_child(number)
		_sector_labels.append(number)
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
	_answer_label = _make_answer_label(_question)
	_keypad = _make_keypad(_question, _on_key)
	_question.visible = false


func _sector_centre(sector: int) -> Vector2:
	var angle := -PI / 2.0 + sector * TAU / PatternLogic.SECTORS
	var radius := minf(_stage.size.x, _stage.size.y) * RADIUS
	return _stage.size * 0.5 + Vector2(cos(angle), sin(angle)) * radius


func _layout() -> void:
	_centre.position = _stage.size * 0.5 - _centre.size * 0.5
	for i in PatternLogic.SECTORS:
		var c := _sector_centre(i)
		_sector_boxes[i].position = c - _sector_boxes[i].size * 0.5
		_sector_labels[i].position = c + Vector2(-20, BAR_SIZE.y * 0.5 + 6)


func _handle_response(event: InputEvent) -> void:
	var label := _keypad_label_from_event(event)
	if label.is_empty():
		return
	if _asking:
		_on_key(label)
	elif _accepting and label.is_valid_int():
		_on_sector(int(label) - 1)
	get_viewport().set_input_as_handled()


func _show_patterns() -> void:
	for i in PatternLogic.SECTORS:
		var box := _sector_boxes[i]
		for child in box.get_children():
			child.queue_free()
		var pattern := _logic.pattern_for(i)
		var bars: int = pattern["bars"]
		var is_target_color: bool = pattern["target_color"]
		for b in bars:
			var bar := ColorRect.new()
			bar.custom_minimum_size = BAR_SIZE
			bar.color = get_theme_color("lit", "Board") if is_target_color else get_theme_color("task_magnitude", "Board")
			box.add_child(bar)
		box.visible = true
	await get_tree().process_frame
	_layout()


func _hide_patterns() -> void:
	for box in _sector_boxes:
		box.visible = false


func _run_trials() -> void:
	_logic = PatternLogic.new(trials, _rng)
	_asking = false
	_question.visible = false
	_centre.text = str(_centre_digit)
	_layout()
	for i in trials:
		_accepting = false
		if not await _wait(_logic.next_gap_ms() / 1000.0):
			return
		if _logic.centre_changes[i]:
			_centre_digit = _logic.next_digit(_centre_digit)
			_centre.text = str(_centre_digit)
			if not await _wait(0.3):
				return
		_show_patterns()
		if not await _wait(PatternLogic.SHOW_MS / 1000.0):
			return
		_hide_patterns()
		_accepting = true
		_set_progress(i)
		while _accepting:
			if not await _wait(0.1):
				return
	_ask_centre_count()


func _on_sector(sector: int) -> void:
	if not _running or not _accepting or sector < 0 or sector >= PatternLogic.SECTORS:
		return
	_accepting = false
	var ok := _logic.answer(sector)
	_sector_labels[sector].add_theme_color_override("font_color", get_theme_color("correct" if ok else "wrong", "Pad"))
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(_sector_labels[sector].remove_theme_color_override.bind("font_color"))
	_set_progress(_logic.current)


func _ask_centre_count() -> void:
	_asking = true
	_answer = ""
	_centre.text = ""
	_question_label.text = tr("PERIPHERAL_QUESTION")
	_answer_label.text = ""
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
	_answer_label.text = _answer


func _reset_play_state() -> void:
	_accepting = false
	_asking = false
	if not _sector_boxes.is_empty():
		_hide_patterns()
