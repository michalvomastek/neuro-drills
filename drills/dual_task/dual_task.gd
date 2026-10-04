## Dual task: tap the rhythm with the left pad or space; after a while
## arithmetic problems appear on the right, answered with the keypad or number
## keys, while the tapping must go on.
extends TrialDrill

const TEMPOS: Array[int] = [60, 90, 120]
const DEFAULT_BPM := 90
const PULSE_SECONDS := 0.12

var _bpm: int = DEFAULT_BPM
var _bpm_option: OptionButton
var _logic: DualTaskLogic
var _tap_pad: Button
var _disc_style: StyleBoxFlat
var _hint: Label
var _problem: Label
var _input: Label
var _keypad: GridContainer
var _answer: String = ""
var _started_ms: int = 0
var _cueing: bool = false
var _accepting: bool = false
var _loaded: bool = false


func _uses_trial_count() -> bool:
	return false


func _build_extras(parent: VBoxContainer) -> void:
	_bpm_option = _add_option_row(parent, "RHYTHM_TEMPO", TEMPOS, _bpm)


func _apply_extra_config(config: Dictionary) -> void:
	var requested: int = config.get("bpm", DEFAULT_BPM)
	if TEMPOS.has(requested):
		_bpm = requested
	_bpm_option.select(_bpm_option.get_item_index(_bpm))


func _collect_extra_config() -> Dictionary:
	return {"bpm": _bpm}


func _on_start_pressed() -> void:
	_bpm = _bpm_option.get_selected_id()
	super()


func _build_play_area(parent: Control) -> void:
	var halves := HBoxContainer.new()
	halves.set_anchors_preset(Control.PRESET_FULL_RECT)
	halves.add_theme_constant_override("separation", 16)
	parent.add_child(halves)
	_tap_pad = _make_pad()
	_tap_pad.pressed.connect(_on_tap)
	halves.add_child(_tap_pad)
	var left_overlay := CenterContainer.new()
	left_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc := Panel.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.custom_minimum_size = Vector2(140, 140)
	_disc_style = StyleBoxFlat.new()
	_disc_style.set_corner_radius_all(70)
	_disc_style.bg_color = get_theme_color("cell", "Board")
	disc.add_theme_stylebox_override("panel", _disc_style)
	left_overlay.add_child(disc)
	_tap_pad.add_child(left_overlay)
	left_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	halves.add_child(right)
	_hint = Label.new()
	_hint.theme_type_variation = &"DimLabel"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 24)
	right.add_child(_hint)
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(stage)
	_problem = _make_stimulus_label(stage, 72)
	_input = Label.new()
	_input.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input.add_theme_font_size_override("font_size", 40)
	_input.custom_minimum_size = Vector2(0, 52)
	right.add_child(_input)
	var center := CenterContainer.new()
	right.add_child(center)
	_keypad = _make_keypad(center, _on_key)
	_keypad.visible = false


func _handle_response(event: InputEvent) -> void:
	# Space taps the rhythm; Enter (main or numpad) confirms an answer instead.
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		_on_tap()
		get_viewport().set_input_as_handled()
		return
	var label := _keypad_label_from_event(event)
	if not label.is_empty():
		_on_key(label)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _cueing:
		return
	var elapsed := Time.get_ticks_msec() - _started_ms
	if int(elapsed / _logic.period_ms()) >= DualTaskLogic.CUED_BEATS:
		_cueing = false
		_disc_style.bg_color = get_theme_color("cell", "Board")
		_hint.text = tr("RHYTHM_CONTINUE")
		return
	var phase := fmod(elapsed, _logic.period_ms()) / 1000.0
	_disc_style.bg_color = get_theme_color("lit", "Board") if phase < PULSE_SECONDS else get_theme_color("cell", "Board")


func _run_trials() -> void:
	_logic = DualTaskLogic.new(_bpm, _rng)
	_loaded = false
	_problem.text = ""
	_input.text = ""
	_keypad.visible = false
	_hint.text = tr("DUAL_HINT_TAP")
	_set_progress_text("%d BPM   0 / %d" % [_bpm, _logic.total_taps()])
	if not await _wait(1.0):
		return
	_started_ms = Time.get_ticks_msec()
	_cueing = true
	_accepting = true


func _on_tap() -> void:
	if not _running or not _accepting:
		return
	_logic.record_tap(Time.get_ticks_msec())
	_flash_pad(_tap_pad, get_theme_color("selected", "Board"), 0.12)
	_set_progress_text("%d BPM   %d / %d" % [_bpm, _logic.taps_ms.size(), _logic.total_taps()])
	if _logic.is_loaded_phase() and not _loaded:
		_loaded = true
		_hint.text = tr("DUAL_HINT_SOLVE")
		_keypad.visible = true
		_next_problem()
	if _logic.is_done():
		_accepting = false
		_cueing = false
		_complete(_logic.build_result(definition.id, get_config()))


func _next_problem() -> void:
	_answer = ""
	_input.text = ""
	_input.remove_theme_color_override("font_color")
	_problem.text = _logic.arithmetic.new_problem()


func _on_key(key: String) -> void:
	if not _running or not _loaded or not _accepting:
		return
	if key == KEY_BACKSPACE_LABEL:
		_answer = _answer.left(-1)
	elif key == KEY_OK_LABEL:
		if not _answer.is_empty():
			if _logic.answer_problem(int(_answer)):
				_next_problem()
			else:
				_input.add_theme_color_override("font_color", get_theme_color("wrong", "Pad"))
				_answer = ""
		return
	elif _answer.length() < 4:
		_answer += key
	_input.text = _answer


func _reset_play_state() -> void:
	_cueing = false
	_accepting = false
	_loaded = false
	if _disc_style != null:
		_disc_style.bg_color = get_theme_color("cell", "Board")
