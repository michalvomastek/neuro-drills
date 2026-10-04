## Corsi blocks: watch the blocks light up, then tap them in the same order.
extends TrialDrill

const SHOW_SECONDS := 0.7
const GAP_SECONDS := 0.3
const FEEDBACK_SECONDS := 0.8

var _logic: CorsiLogic
var _board: Control
var _blocks: Array[Button] = []
var _answer: Array[int] = []
var _accepting: bool = false


func _uses_trial_count() -> bool:
	return false


func _build_play_area(parent: Control) -> void:
	_board = _make_square_board(parent)
	_board.resized.connect(_layout_blocks)
	for i in CorsiLogic.BLOCK_COUNT:
		var block := _make_pad()
		block.size_flags_horizontal = Control.SIZE_FILL
		block.size_flags_vertical = Control.SIZE_FILL
		block.pressed.connect(_on_block_pressed.bind(i))
		_board.add_child(block)
		_blocks.append(block)
	_layout_blocks()


func _layout_blocks() -> void:
	var side := minf(_board.size.x, _board.size.y)
	for i in _blocks.size():
		_blocks[i].position = CorsiLogic.LAYOUT[i] * side
		_blocks[i].size = Vector2.ONE * CorsiLogic.BLOCK_SIZE * side


func _run_trials() -> void:
	_logic = CorsiLogic.new(_rng)
	_play_round()


func _play_round() -> void:
	_accepting = false
	_answer.clear()
	_set_progress_text(tr("SPAN_LENGTH") % _logic.tracker.length)
	var sequence := _logic.new_sequence()
	if not await _wait(0.8):
		return
	for block in sequence:
		_set_pad_color(_blocks[block], get_theme_color("lit", "Board"))
		if not await _wait(SHOW_SECONDS):
			return
		_clear_pad_flash(_blocks[block])
		if not await _wait(GAP_SECONDS):
			return
	_accepting = true


func _on_block_pressed(index: int) -> void:
	if not _running or not _accepting:
		return
	_answer.append(index)
	_flash_pad(_blocks[index], get_theme_color("lit", "Board"), 0.3)
	if _answer.size() < _logic.sequence.size():
		return
	_accepting = false
	var success := _logic.check(_answer.duplicate())
	for block in _logic.sequence:
		_flash_pad(_blocks[block], get_theme_color("correct" if success else "wrong", "Pad"), FEEDBACK_SECONDS)
	if not await _wait(FEEDBACK_SECONDS):
		return
	if _logic.tracker.done:
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_play_round()
