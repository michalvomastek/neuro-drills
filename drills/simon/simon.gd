## Simon: watch the colour sequence, then repeat it; it grows by one each round.
extends TrialDrill

const SHOW_SECONDS := 0.45
const GAP_SECONDS := 0.2
const FEEDBACK_SECONDS := 0.9
const PAD_COLORS: Array[Color] = [
	Color(0.75, 0.22, 0.22),
	Color(0.22, 0.62, 0.32),
	Color(0.25, 0.47, 0.9),
	Color(0.9, 0.78, 0.2),
]

var _logic: SimonLogic
var _pads: Array[Button] = []
var _accepting: bool = false


func _uses_trial_count() -> bool:
	return false


func _build_play_area(parent: Control) -> void:
	var board := _make_square_board(parent)
	var grid := GridContainer.new()
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	board.add_child(grid)
	for i in SimonLogic.PAD_COUNT:
		var pad := _make_pad()
		pad.pressed.connect(_on_pad_pressed.bind(i))
		grid.add_child(pad)
		_pads.append(pad)
		_dim(i)


func _dim(index: int) -> void:
	_set_pad_color(_pads[index], PAD_COLORS[index].darkened(0.55))


func _light(index: int) -> void:
	_set_pad_color(_pads[index], PAD_COLORS[index].lightened(0.15))


func _run_trials() -> void:
	_logic = SimonLogic.new(_rng)
	_play_round()


func _play_round() -> void:
	_accepting = false
	var sequence := _logic.extend()
	_set_progress_text(tr("SPAN_LENGTH") % sequence.size())
	if not await _wait(0.8):
		return
	for pad in sequence:
		_light(pad)
		if not await _wait(SHOW_SECONDS):
			return
		_dim(pad)
		if not await _wait(GAP_SECONDS):
			return
	_accepting = true


func _on_pad_pressed(index: int) -> void:
	if not _running or not _accepting:
		return
	_light(index)
	var ok := _logic.press(index)
	_blink_back(index)
	if not ok:
		_accepting = false
		_set_pad_color(_pads[_logic.sequence[_logic.step]], get_theme_color("wrong", "Pad"))
		if not await _wait(FEEDBACK_SECONDS):
			return
		_complete(_logic.build_result(definition.id, get_config()))
		return
	if _logic.round_complete():
		_accepting = false
		if not await _wait(0.5):
			return
		if _logic.is_done():
			_complete(_logic.build_result(definition.id, get_config()))
		else:
			_play_round()


func _blink_back(index: int) -> void:
	if not await _wait(0.25):
		return
	if not _logic.failed or index != _logic.sequence[_logic.step]:
		_dim(index)
