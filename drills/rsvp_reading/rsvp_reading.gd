## RSVP reading: words flash in the centre one by one; answer a question afterwards.
extends TrialDrill

const SPEEDS: Array[int] = [200, 300, 400, 500, 650]
const DEFAULT_WPM := 300

var _wpm: int = DEFAULT_WPM
var _wpm_option: OptionButton
var _logic: RsvpLogic
var _word: Label
var _question_box: VBoxContainer
var _question_label: Label
var _answer_buttons: Array[Button] = []


func _uses_trial_count() -> bool:
	return false


func _build_extras(parent: VBoxContainer) -> void:
	_wpm_option = _add_option_row(parent, "RSVP_SPEED", SPEEDS, _wpm)


func _apply_extra_config(config: Dictionary) -> void:
	var requested: int = config.get("wpm", DEFAULT_WPM)
	if SPEEDS.has(requested):
		_wpm = requested
	_wpm_option.select(_wpm_option.get_item_index(_wpm))


func _collect_extra_config() -> Dictionary:
	return {"wpm": _wpm}


func _on_start_pressed() -> void:
	_wpm = _wpm_option.get_selected_id()
	super()


func _build_play_area(parent: Control) -> void:
	_word = _make_stimulus_label(parent, 72)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	_question_box = VBoxContainer.new()
	_question_box.custom_minimum_size = Vector2(640, 0)
	_question_box.add_theme_constant_override("separation", 16)
	center.add_child(_question_box)
	_question_label = Label.new()
	_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question_label.add_theme_font_size_override("font_size", 28)
	_question_box.add_child(_question_label)
	for i in 3:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_answer.bind(i))
		_question_box.add_child(button)
		_answer_buttons.append(button)
	_question_box.visible = false


func _run_trials() -> void:
	var passage_index := RsvpLogic.pick_passage(_rng)
	var text_key: String = RsvpLogic.PASSAGES[passage_index]["text"]
	_logic = RsvpLogic.new(_wpm, passage_index, tr(text_key))
	_question_box.visible = false
	for button in _answer_buttons:
		button.remove_theme_color_override("font_color")
	_set_progress_text("%d %s" % [_wpm, tr("RSVP_WPM_UNIT")])
	_word.text = "•"
	if not await _wait(1.0):
		return
	for word in _logic.words:
		_word.text = word
		if not await _wait(_logic.seconds_per_word()):
			return
	_word.text = ""
	var question_key: String = _logic.passage["question"]
	_question_label.text = tr(question_key)
	var answers: Array = _logic.passage["answers"]
	for i in _answer_buttons.size():
		var key: String = answers[i]
		_answer_buttons[i].text = tr(key)
	_question_box.visible = true
	_answer_buttons[0].grab_focus()


func _on_answer(index: int) -> void:
	if not _running or _logic.answered:
		return
	var correct := _logic.answer(index)
	_answer_buttons[index].add_theme_color_override("font_color", get_theme_color("correct" if correct else "wrong", "Pad"))
	if not await _wait(0.8):
		return
	_complete(_logic.build_result(definition.id, get_config()))
