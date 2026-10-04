## SART: digits flash one after another; respond to all of them except 3.
extends TrialDrill

var _logic: SartLogic
var _pad: Button
var _digit: Label
var _window_open: bool = false
var _stimulus_ms: int = 0


func _trial_options() -> Array[int]:
	return [45, 90, 135]


func _default_trials() -> int:
	return 45


func _build_play_area(parent: Control) -> void:
	_pad = _make_pad()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.pressed.connect(_on_response)
	parent.add_child(_pad)
	_digit = _make_stimulus_label(parent, 160)


func _handle_response(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_response()
		get_viewport().set_input_as_handled()


func _reset_play_state() -> void:
	_window_open = false
	if _digit != null:
		_digit.text = ""


func _run_trials() -> void:
	_logic = SartLogic.new(trials, _rng)
	if not await _wait(1.0):
		return
	for i in trials:
		_digit.text = str(_logic.current_digit())
		_stimulus_ms = Time.get_ticks_msec()
		_window_open = true
		if not await _wait(SartLogic.STIMULUS_MS / 1000.0):
			return
		_digit.text = ""
		if not await _wait((SartLogic.INTERVAL_MS - SartLogic.STIMULUS_MS) / 1000.0):
			return
		_window_open = false
		_logic.close_window()
		_set_progress(i + 1)
	_complete(_logic.build_result(definition.id, get_config()))


func _on_response() -> void:
	if not _running or not _window_open:
		return
	var correct := _logic.respond(Time.get_ticks_msec() - _stimulus_ms)
	if not correct:
		_flash_pad(_pad, get_theme_color("wrong_dim", "Pad"), 0.4)
