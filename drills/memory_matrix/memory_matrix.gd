## Memory matrix: remember which cells lit up and tap them back.
extends TrialDrill

const SIZES: Array[int] = [4, 5, 6]
const DEFAULT_SIZE := 5
const SHOW_SECONDS := 1.6
const FEEDBACK_SECONDS := 0.9

var _size: int = DEFAULT_SIZE
var _size_option: OptionButton
var _logic: MatrixLogic
var _board: Control
var _grid: GridContainer
var _cells: Array[Button] = []
var _accepting: bool = false


func _trial_options() -> Array[int]:
	return [8, 12, 16]


func _default_trials() -> int:
	return 12


func _build_extras(parent: VBoxContainer) -> void:
	_size_option = _add_option_row(parent, "MATRIX_SIZE", SIZES, _size)


func _apply_extra_config(config: Dictionary) -> void:
	var requested: int = config.get("size", DEFAULT_SIZE)
	if SIZES.has(requested):
		_size = requested
	_size_option.select(_size_option.get_item_index(_size))


func _collect_extra_config() -> Dictionary:
	return {"size": _size}


func _on_start_pressed() -> void:
	_size = _size_option.get_selected_id()
	super()


func _build_play_area(parent: Control) -> void:
	_board = _make_square_board(parent)
	_grid = GridContainer.new()
	_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_board.add_child(_grid)


func _build_grid() -> void:
	for cell in _cells:
		cell.queue_free()
	_cells.clear()
	_grid.columns = _size
	for i in _size * _size:
		var cell := _make_pad()
		cell.pressed.connect(_on_cell_pressed.bind(i))
		_grid.add_child(cell)
		_cells.append(cell)


func _run_trials() -> void:
	_logic = MatrixLogic.new(_size, trials, _rng)
	_build_grid()
	_play_round()


func _play_round() -> void:
	_accepting = false
	for cell in _cells:
		_clear_pad_flash(cell)
	_set_progress_text("%s %d   %d / %d" % [tr("MATRIX_LEVEL"), _logic.level, _logic.rounds_done, trials])
	var pattern := _logic.new_round()
	if not await _wait(0.7):
		return
	for index in pattern:
		_set_pad_color(_cells[index], get_theme_color("lit", "Board"))
	if not await _wait(SHOW_SECONDS):
		return
	for index in pattern:
		_clear_pad_flash(_cells[index])
	_accepting = true


func _on_cell_pressed(index: int) -> void:
	if not _running or not _accepting:
		return
	if not _logic.select(index):
		return
	_set_pad_color(_cells[index], get_theme_color("selected", "Board"))
	if not _logic.is_round_complete():
		return
	_accepting = false
	_logic.finish_round()
	for cell in _logic.pattern:
		_set_pad_color(_cells[cell], get_theme_color("correct", "Pad"))
	for cell in _logic.selected:
		if not _logic.pattern.has(cell):
			_set_pad_color(_cells[cell], get_theme_color("wrong", "Pad"))
	if not await _wait(FEEDBACK_SECONDS):
		return
	if _logic.is_done():
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_play_round()
