## Multiple object tracking: remember the highlighted discs, follow them while
## everything moves, then click them.
extends TrialDrill

const FEEDBACK_SECONDS := 1.2

var _logic: MotLogic
var _board: MotBoard
var _moving: bool = false
var _move_left: float = 0.0
var _picking: bool = false
var _pick_started_usec: int = 0


func _trial_options() -> Array[int]:
	return [5, 8, 12]


func _default_trials() -> int:
	return 5


func _build_play_area(parent: Control) -> void:
	_board = MotBoard.new()
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.disc_clicked.connect(_on_disc_clicked)
	parent.add_child(_board)


func _process(delta: float) -> void:
	if not _moving:
		return
	_logic.step(delta)
	_board.queue_redraw()
	_move_left -= delta
	if _move_left <= 0.0:
		_moving = false
		_picking = true
		_pick_started_usec = Time.get_ticks_usec()
		_board.show_selection = true
		_board.queue_redraw()


func _reset_play_state() -> void:
	_moving = false
	_picking = false


func _run_trials() -> void:
	_logic = MotLogic.new(trials, _rng)
	_board.logic = _logic
	_play_round()


func _play_round() -> void:
	_picking = false
	_board.reveal = false
	_board.show_selection = false
	_logic.new_round()
	_board.highlight_targets = true
	_board.queue_redraw()
	_set_progress(_logic.round_index)
	if not await _wait(MotLogic.SHOW_SECONDS):
		return
	_board.highlight_targets = false
	_move_left = MotLogic.MOVE_SECONDS
	_moving = true


func _on_disc_clicked(index: int) -> void:
	if not _running or not _picking:
		return
	_logic.select(index)
	_board.queue_redraw()
	if not _logic.is_round_complete():
		return
	_picking = false
	_logic.times_ms.append((Time.get_ticks_usec() - _pick_started_usec) / 1000.0)
	_logic.finish_round()
	_board.reveal = true
	_board.queue_redraw()
	if not await _wait(FEEDBACK_SECONDS):
		return
	if _logic.is_done():
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_play_round()
