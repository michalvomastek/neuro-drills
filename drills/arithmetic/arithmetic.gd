## Arithmetic sprint: solve as many problems as you can before the time runs out.
extends TrialDrill

const DURATIONS: Array[int] = [30, 60, 90]
const DEFAULT_DURATION := 60

var _duration: int = DEFAULT_DURATION
var _duration_option: OptionButton
var _logic: ArithmeticLogic
var _problem: Label
var _input: Label
var _keypad: GridContainer
var _answer: String = ""
var _problem_ms: int = 0
var _ends_at_ms: int = 0
var _accepting: bool = false


func _uses_trial_count() -> bool:
	return false


func _build_extras(parent: VBoxContainer) -> void:
	_duration_option = _add_option_row(parent, "ARITH_DURATION", DURATIONS, _duration)


func _apply_extra_config(config: Dictionary) -> void:
	var requested: int = config.get("duration_s", DEFAULT_DURATION)
	if DURATIONS.has(requested):
		_duration = requested
	_duration_option.select(_duration_option.get_item_index(_duration))


func _collect_extra_config() -> Dictionary:
	return {"duration_s": _duration}


func _on_start_pressed() -> void:
	_duration = _duration_option.get_selected_id()
	super()


func _build_play_area(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	parent.add_child(vbox)
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(stage)
	_problem = _make_stimulus_label(stage, 96)
	_input = Label.new()
	_input.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input.add_theme_font_size_override("font_size", 48)
	_input.custom_minimum_size = Vector2(0, 64)
	vbox.add_child(_input)
	var center := CenterContainer.new()
	vbox.add_child(center)
	_keypad = _make_keypad(center, _on_key)


func _handle_response(event: InputEvent) -> void:
	var label := _keypad_label_from_event(event)
	if label.is_empty():
		return
	_on_key(label)
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _accepting:
		var remaining := maxi(0, _ends_at_ms - Time.get_ticks_msec())
		_set_progress_text("%s   %d" % [Format.seconds_short(remaining), _logic.correct_count])


func _run_trials() -> void:
	_logic = ArithmeticLogic.new(_duration, _rng)
	_ends_at_ms = Time.get_ticks_msec() + _duration * 1000
	_accepting = true
	_next_problem()
	if not await _wait(_duration):
		return
	_accepting = false
	_complete(_logic.build_result(definition.id, get_config()))


func _next_problem() -> void:
	_answer = ""
	_input.text = ""
	_input.remove_theme_color_override("font_color")
	_problem.text = _logic.new_problem()
	_problem_ms = Time.get_ticks_msec()


func _on_key(key: String) -> void:
	if not _running or not _accepting:
		return
	if key == KEY_BACKSPACE_LABEL:
		_answer = _answer.left(-1)
	elif key == KEY_OK_LABEL:
		if not _answer.is_empty():
			_submit()
		return
	elif _answer.length() < 4:
		_answer += key
	_input.text = _answer


func _submit() -> void:
	var correct := _logic.check(int(_answer), Time.get_ticks_msec() - _problem_ms)
	if correct:
		_next_problem()
	else:
		_input.add_theme_color_override("font_color", get_theme_color("wrong", "Pad"))
		_answer = ""
