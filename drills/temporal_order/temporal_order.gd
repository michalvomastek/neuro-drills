## Temporal order judgment: two discs light up almost together; press the side
## that lit up first. Timing runs in _process so it is frame-accurate.
extends TrialDrill

const GAP_SECONDS := 0.7

var _logic: TojLogic
var _pads: Array[Button] = []
var _labels: Array[Label] = []
var _accepting: bool = false
var _playing: bool = false
var _elapsed_ms: float = 0.0
var _shown: Array[bool] = [false, false]


func _trial_options() -> Array[int]:
	return [20, 30, 40]


func _default_trials() -> int:
	return 20


func _build_play_area(parent: Control) -> void:
	_pads = _make_side_pads(parent)
	for side in _pads.size():
		_pads[side].text = ""
		_pads[side].pressed.connect(_on_side_pressed.bind(side))
	_labels = _make_side_labels(parent, 180)


func _handle_response(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_on_side_pressed(0)
	elif event.is_action_pressed("ui_right"):
		_on_side_pressed(1)
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _playing:
		return
	var first := _logic.first_side
	if not _shown[first]:
		# The clock starts on the frame the first disc is drawn, so the second
		# one is always at least one frame later.
		_shown[first] = true
		_labels[first].text = "●"
		_elapsed_ms = 0.0
		return
	_elapsed_ms += delta * 1000.0
	if not _shown[1 - first] and _elapsed_ms >= _logic.soa_ms():
		_shown[1 - first] = true
		_labels[1 - first].text = "●"
	if _elapsed_ms >= _logic.soa_ms() + TojLogic.HOLD_MS:
		_playing = false
		for label in _labels:
			label.text = ""
		_accepting = true


func _reset_play_state() -> void:
	_playing = false
	_accepting = false
	if not _labels.is_empty():
		for label in _labels:
			label.text = ""


func _run_trials() -> void:
	_logic = TojLogic.new(trials, _rng)
	_next_trial()


func _next_trial() -> void:
	_accepting = false
	_playing = false
	for label in _labels:
		label.text = ""
	_set_progress_text("%d ms   %d / %d" % [roundi(_logic.soa_ms()), _logic.current, trials])
	if not await _wait(GAP_SECONDS):
		return
	_logic.new_trial()
	_shown = [false, false]
	_elapsed_ms = 0.0
	_playing = true


func _on_side_pressed(side: int) -> void:
	if not _running or not _accepting:
		return
	_accepting = false
	var correct := _logic.answer(side)
	_flash_pad(_pads[side], get_theme_color("correct" if correct else "wrong", "Pad"), 0.4)
	if not await _wait(0.4):
		return
	if _logic.is_done():
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_next_trial()
