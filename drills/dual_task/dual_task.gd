## Dual task: tap the rhythm with the left pad or space; after a while
## arithmetic problems appear on the right, answered with the keypad or number
## keys, while the tapping must go on. The keypad is on screen from the start
## (greyed out), so nothing moves under the tapping finger when the load
## begins; a phone stacks the pad above the problem instead of beside it. The
## problem and the digits typed so far share one line ("54 + 39 = 9"), which
## fits a short phone screen above the keypad.
extends TrialDrill

const TEMPOS: Array[int] = [60, 90, 120]
const DEFAULT_BPM := 90
const PULSE_SECONDS := 0.12
const PROBLEM_FONT_SIZE := 72

var _bpm: int = DEFAULT_BPM
var _bpm_option: OptionButton
var _logic: DualTaskLogic
var _tap_pad: Button
var _disc_style: StyleBoxFlat
var _hint: Label
var _problem: Label
var _problem_text: String = ""
var _keypad: GridContainer
var _halves: BoxContainer
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
	var halves := BoxContainer.new()
	halves.set_anchors_preset(Control.PRESET_FULL_RECT)
	halves.add_theme_constant_override("separation", 16)
	parent.add_child(halves)
	_halves = halves
	_tap_pad = _make_pad()
	_tap_pad.custom_minimum_size = Vector2(0, 160)
	_tap_pad.pressed.connect(_on_tap)
	halves.add_child(_tap_pad)
	var left_overlay := CenterContainer.new()
	# Anchors go on before the overlay has a parent: set_anchors_preset() on a
	# parented control keeps its current rect by rewriting the offsets, which
	# froze the overlay at the pad's minimum size.
	left_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	# The stage reserves the digits' height, not the whole line box: with no
	# minimum the keypad squeezed it to nothing on a phone and the equation
	# spilled over the row below. The box's empty line spacing overhangs the
	# stage both ways, so the digits stay centred in it.
	stage.custom_minimum_size = Vector2(0, roundi(PROBLEM_FONT_SIZE * Layout.CAP_HEIGHT_RATIO))
	right.add_child(stage)
	_problem = Label.new()
	_problem.set_anchors_preset(Control.PRESET_FULL_RECT)
	_problem.grow_vertical = Control.GROW_DIRECTION_BOTH
	_problem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_problem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_problem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_problem.add_theme_font_size_override("font_size", PROBLEM_FONT_SIZE)
	stage.add_child(_problem)
	stage.resized.connect(_size_equation.bind(stage))
	var center := CenterContainer.new()
	right.add_child(center)
	_keypad = _make_keypad(center, _on_key)
	_set_keypad_enabled(false)
	_relayout_setup()


## Sizes the equation's font once per layout so the widest equation the
## drill can show fits [param stage]; the line then stays put while the
## answer is typed instead of shrinking with every digit.
func _size_equation(stage: Control) -> void:
	var available := stage.size.x - 32.0
	if available <= 0.0:
		return
	var font := _problem.get_theme_font("font")
	var widest := 0.0
	for symbol: String in ["+", "−", "×"]:
		widest = maxf(widest, font.get_string_size("88 %s 88 = 8888" % symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, PROBLEM_FONT_SIZE).x)
	var fitted := PROBLEM_FONT_SIZE if widest <= available else maxi(16, int(PROBLEM_FONT_SIZE * available / widest))
	_problem.add_theme_font_size_override("font_size", fitted)


## Side by side on a wide screen, the pad above the problem on a phone.
func _relayout_setup() -> void:
	super()
	if _halves != null:
		_halves.vertical = Layout.is_narrow(self)


func _set_keypad_enabled(enabled: bool) -> void:
	for child in _keypad.get_children():
		var button := child as Button
		if button != null:
			button.disabled = not enabled


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
	_problem_text = ""
	_problem.text = ""
	_problem.remove_theme_color_override("font_color")
	_set_keypad_enabled(false)
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
		_set_keypad_enabled(true)
		_next_problem()
	if _logic.is_done():
		_accepting = false
		_cueing = false
		_complete(_logic.build_result(definition.id, get_config()))


func _next_problem() -> void:
	_answer = ""
	_problem_text = _logic.arithmetic.new_problem()
	_problem.remove_theme_color_override("font_color")
	_show_equation()


## "54 + 39 =" with the digits typed so far after the equals sign.
func _show_equation() -> void:
	_problem.text = ("%s = %s" % [_problem_text, _answer]).strip_edges()


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
				# The wrong digits stay on screen in red until the next answer.
				_problem.add_theme_color_override("font_color", get_theme_color("wrong", "Pad"))
				_answer = ""
		return
	elif _answer.length() < 4:
		_answer += key
	_show_equation()


func _reset_play_state() -> void:
	_cueing = false
	_accepting = false
	_loaded = false
	if _disc_style != null:
		_disc_style.bg_color = get_theme_color("cell", "Board")
	if _problem != null:
		_problem.remove_theme_color_override("font_color")
	if _keypad != null:
		_set_keypad_enabled(false)
