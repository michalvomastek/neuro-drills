## Flanker task: five arrows, respond to the middle one with the matching side.
extends TrialDrill

const FEEDBACK_SECONDS := 0.4

var _logic: FlankerLogic
var _pads: Array[Button] = []
var _stimulus: Label
var _awaiting_response: bool = false
var _stimulus_ms: int = 0


func _trial_options() -> Array[int]:
	return [12, 24, 48]


func _default_trials() -> int:
	return 24


func _build_play_area(parent: Control) -> void:
	_pads = _make_side_pads(parent)
	for side in _pads.size():
		_pads[side].text = ""
		_pads[side].pressed.connect(_on_side_pressed.bind(side))
	_stimulus = _make_stimulus_label(parent, 120)


func _handle_response(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_on_side_pressed(0)
	elif event.is_action_pressed("ui_right"):
		_on_side_pressed(1)
	else:
		return
	get_viewport().set_input_as_handled()


func _run_trials() -> void:
	_logic = FlankerLogic.new(trials, _rng)
	_next_trial()


func _next_trial() -> void:
	_stimulus.text = ""
	_awaiting_response = false
	if not await _wait(_logic.next_delay_ms() / 1000.0):
		return
	_stimulus.text = " ".join(_logic.current_stimulus().split(""))
	_stimulus_ms = Time.get_ticks_msec()
	_awaiting_response = true


func _on_side_pressed(side: int) -> void:
	if not _running or not _awaiting_response:
		return
	_awaiting_response = false
	var correct := _logic.record_response(side, Time.get_ticks_msec() - _stimulus_ms)
	_flash_pad(_pads[side], get_theme_color("correct" if correct else "wrong", "Pad"), FEEDBACK_SECONDS)
	_set_progress(_logic.current)
	if not await _wait(FEEDBACK_SECONDS):
		return
	if _logic.is_done():
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_next_trial()
