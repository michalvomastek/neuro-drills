## Stroop test: name the ink colour of a colour word with the buttons or keys 1-4.
extends TrialDrill

const FEEDBACK_SECONDS := 0.35
const GAP_SECONDS := 0.5
const COLOR_KEYS: Array[String] = ["COLOR_RED", "COLOR_GREEN", "COLOR_BLUE", "COLOR_YELLOW"]
const COLORS: Array[Color] = [
	Color(0.9, 0.27, 0.27),
	Color(0.27, 0.75, 0.38),
	Color(0.33, 0.56, 1.0),
	Color(0.95, 0.85, 0.25),
]
const KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]

var _logic: StroopLogic
var _word: Label
var _buttons: Array[Button] = []
var _awaiting_response: bool = false
var _stimulus_ms: int = 0


func _trial_options() -> Array[int]:
	return [12, 24, 48]


func _default_trials() -> int:
	return 24


func _build_play_area(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	parent.add_child(vbox)
	var word_area := Control.new()
	word_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(word_area)
	_word = _make_stimulus_label(word_area, 110)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(row)
	for i in StroopLogic.COLOR_COUNT:
		var button := _make_pad(str(i + 1), 36)
		button.size_flags_vertical = Control.SIZE_FILL
		var style := (get_theme_stylebox("normal", "Pad") as StyleBoxFlat).duplicate() as StyleBoxFlat
		style.bg_color = COLORS[i]
		for state in PAD_STATES:
			button.add_theme_stylebox_override(state, style)
		button.add_theme_color_override("font_color", Color(0, 0, 0, 0.7))
		button.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0.7))
		button.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0.7))
		button.pressed.connect(_on_color_pressed.bind(i))
		row.add_child(button)
		_buttons.append(button)


func _handle_response(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var index := KEYS.find(key.keycode)
	if index < 0:
		index = KEYS.find(key.physical_keycode)
	if index >= 0:
		_on_color_pressed(index)
		get_viewport().set_input_as_handled()


func _run_trials() -> void:
	_logic = StroopLogic.new(trials, _rng)
	_next_trial()


func _next_trial() -> void:
	_word.text = ""
	_awaiting_response = false
	if not await _wait(GAP_SECONDS):
		return
	_word.text = tr(COLOR_KEYS[_logic.word_index[_logic.current]])
	_word.add_theme_color_override("font_color", COLORS[_logic.ink_index[_logic.current]])
	_stimulus_ms = Time.get_ticks_msec()
	_awaiting_response = true


func _on_color_pressed(color: int) -> void:
	if not _running or not _awaiting_response:
		return
	_awaiting_response = false
	var correct := _logic.record_response(color, Time.get_ticks_msec() - _stimulus_ms)
	if not correct:
		_word.add_theme_color_override("font_color", get_theme_color("font_color", "DimLabel"))
		_word.text = "✕"
	_set_progress(_logic.current)
	if not await _wait(FEEDBACK_SECONDS):
		return
	if _logic.is_done():
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_next_trial()
