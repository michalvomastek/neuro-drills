## Peripheral reading: read the letters in the middle and count the target
## letter, while discs slide past on both sides and the red ones must be
## counted too. Both counts are entered at the end.
extends TrialDrill

const DISC_SIZE := 54.0

var _logic: ReadingLogic
var _stage: Control
var _letter: Label
var _target_hint: Label
var _discs: Array[Panel] = []
var _question: VBoxContainer
var _question_label: Label
var _answer_label: Label
var _keypad: GridContainer
var _answer: String = ""
var _asking_step: int = 0
var _letters_seen: int = 0


func _trial_options() -> Array[int]:
	return [20, 30, 45]


func _default_trials() -> int:
	return 20


func _build_play_area(parent: Control) -> void:
	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.clip_contents = true
	parent.add_child(_stage)
	_letter = _make_stimulus_label(_stage, 120)
	_target_hint = Label.new()
	_target_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_target_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_hint.theme_type_variation = &"DimLabel"
	_target_hint.add_theme_font_size_override("font_size", 24)
	_stage.add_child(_target_hint)
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


func _handle_response(event: InputEvent) -> void:
	var label := _keypad_label_from_event(event)
	if label.is_empty() or _asking_step == 0:
		return
	_on_key(label)
	get_viewport().set_input_as_handled()


func _spawn_disc(side: int, red: bool) -> void:
	var disc := Panel.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.size = Vector2(DISC_SIZE, DISC_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = get_theme_color("wrong", "Pad") if red else get_theme_color("lit", "Board")
	style.set_corner_radius_all(roundi(DISC_SIZE / 2.0))
	disc.add_theme_stylebox_override("panel", style)
	var x := _stage.size.x * (0.12 if side == 0 else 0.88) - DISC_SIZE * 0.5
	disc.position = Vector2(x, -DISC_SIZE)
	_stage.add_child(disc)
	_discs.append(disc)
	var tween := disc.create_tween()
	tween.tween_property(disc, "position:y", _stage.size.y + DISC_SIZE, 1.6)
	tween.tween_callback(_remove_disc.bind(disc))


func _remove_disc(disc: Panel) -> void:
	_discs.erase(disc)
	disc.queue_free()


func _run_trials() -> void:
	_logic = ReadingLogic.new(trials, _rng)
	_asking_step = 0
	_question.visible = false
	_target_hint.text = tr("READING_TARGET_HINT") % _logic.target_letter
	_letter.text = ""
	if not await _wait(1.5):
		return
	for i in trials:
		_letter.text = _logic.letters[i]
		_spawn_disc(i % 2, _logic.disc_is_red[i])
		_set_progress(i + 1)
		if not await _wait(ReadingLogic.LETTER_MS / 1000.0):
			return
	_letter.text = ""
	if not await _wait(1.0):
		return
	_ask(1)


func _ask(step: int) -> void:
	_asking_step = step
	_answer = ""
	_target_hint.text = ""
	_question_label.text = tr("READING_Q_LETTERS") % _logic.target_letter if step == 1 else tr("READING_Q_REDS")
	_answer_label.text = ""
	_question.visible = true


func _on_key(key: String) -> void:
	if not _running or _asking_step == 0:
		return
	if key == KEY_BACKSPACE_LABEL:
		_answer = _answer.left(-1)
	elif key == KEY_OK_LABEL:
		if _answer.is_empty():
			return
		if _asking_step == 1:
			_letters_seen = int(_answer)
			_ask(2)
		else:
			_logic.report(_letters_seen, int(_answer))
			_asking_step = 0
			_complete(_logic.build_result(definition.id, get_config()))
		return
	elif _answer.length() < 2:
		_answer += key
	_answer_label.text = _answer


func _reset_play_state() -> void:
	_asking_step = 0
	for disc in _discs:
		disc.queue_free()
	_discs.clear()
