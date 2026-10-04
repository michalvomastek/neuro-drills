## Visual search: find the one letter that differs and click it.
extends TrialDrill

const SIZES: Array[int] = [16, 36, 64]
const DEFAULT_SIZE := 36
const GAP_SECONDS := 0.5

var _set_size: int = DEFAULT_SIZE
var _size_option: OptionButton
var _logic: SearchLogic
var _board: Control
var _grid: GridContainer
var _cells: Array[Button] = []
var _stimulus_ms: int = 0
var _accepting: bool = false


func _trial_options() -> Array[int]:
	return [10, 20, 30]


func _default_trials() -> int:
	return 10


func _build_extras(parent: VBoxContainer) -> void:
	_size_option = _add_option_row(parent, "SEARCH_SET_SIZE", SIZES, _set_size)


func _apply_extra_config(config: Dictionary) -> void:
	var requested: int = config.get("set_size", DEFAULT_SIZE)
	if SIZES.has(requested):
		_set_size = requested
	_size_option.select(_size_option.get_item_index(_set_size))


func _collect_extra_config() -> Dictionary:
	return {"set_size": _set_size}


func _on_start_pressed() -> void:
	_set_size = _size_option.get_selected_id()
	super()


func _build_play_area(parent: Control) -> void:
	_board = _make_square_board(parent)
	_grid = GridContainer.new()
	_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_board.add_child(_grid)
	_grid.resized.connect(_update_font_size)


func _run_trials() -> void:
	_logic = SearchLogic.new(trials, _set_size, _rng)
	for cell in _cells:
		cell.queue_free()
	_cells.clear()
	var columns := roundi(sqrt(_set_size))
	_grid.columns = columns
	for i in _set_size:
		var cell := _make_pad()
		cell.pressed.connect(_on_cell_pressed.bind(i))
		_grid.add_child(cell)
		_cells.append(cell)
	_update_font_size()
	_next_trial()


func _update_font_size() -> void:
	if _cells.is_empty():
		return
	var cell_height := _grid.size.y / maxi(1, _grid.columns)
	for cell in _cells:
		cell.add_theme_font_size_override("font_size", maxi(12, int(cell_height * 0.5)))


func _next_trial() -> void:
	_accepting = false
	for cell in _cells:
		cell.text = ""
	if not await _wait(GAP_SECONDS):
		return
	for i in _cells.size():
		_cells[i].text = _logic.letter_at(i)
	_stimulus_ms = Time.get_ticks_msec()
	_accepting = true


func _on_cell_pressed(index: int) -> void:
	if not _running or not _accepting:
		return
	var correct := _logic.record_click(index, Time.get_ticks_msec() - _stimulus_ms)
	if not correct:
		_flash_pad(_cells[index], get_theme_color("wrong", "Pad"), 0.3)
		return
	_accepting = false
	_flash_pad(_cells[index], get_theme_color("correct", "Pad"), 0.3)
	_set_progress(_logic.current)
	if not await _wait(0.3):
		return
	if _logic.is_done():
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_next_trial()
