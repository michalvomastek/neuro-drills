## Visual N-back on a 3x3 grid: click or press space when the lit square is in
## the same place as N steps ago.
extends TrialDrill

const LEVELS: Array[int] = [1, 2, 3]
const DEFAULT_LEVEL := 2

var _level: int = DEFAULT_LEVEL
var _level_option: OptionButton
var _logic: NBackLogic
var _pad: Button
var _cells: Array[Panel] = []
var _cell_style: StyleBoxFlat
var _lit_style: StyleBoxFlat
var _current: int = -1
var _window_open: bool = false


func _trial_options() -> Array[int]:
	return [20, 30, 40]


func _default_trials() -> int:
	return 20


func _build_extras(parent: VBoxContainer) -> void:
	_level_option = _add_option_row(parent, "NBACK_LEVEL", LEVELS, _level)


func _apply_extra_config(config: Dictionary) -> void:
	var requested: int = config.get("n", DEFAULT_LEVEL)
	if LEVELS.has(requested):
		_level = requested
	_level_option.select(_level_option.get_item_index(_level))


func _collect_extra_config() -> Dictionary:
	return {"n": _level}


func _build_play_area(parent: Control) -> void:
	_pad = _make_pad()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.pressed.connect(_on_response)
	parent.add_child(_pad)
	var board := _make_square_board(parent)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grid := GridContainer.new()
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.columns = 3
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	board.add_child(grid)
	_cell_style = StyleBoxFlat.new()
	_cell_style.bg_color = get_theme_color("cell", "Board")
	_cell_style.set_corner_radius_all(8)
	_lit_style = _cell_style.duplicate() as StyleBoxFlat
	_lit_style.bg_color = get_theme_color("lit", "Board")
	for i in NBackLogic.POSITIONS:
		var cell := Panel.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.add_theme_stylebox_override("panel", _cell_style)
		grid.add_child(cell)
		_cells.append(cell)


func _handle_response(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_response()
		get_viewport().set_input_as_handled()


func _on_start_pressed() -> void:
	_level = _level_option.get_selected_id()
	super()


func _reset_play_state() -> void:
	_window_open = false
	_current = -1
	for cell in _cells:
		cell.add_theme_stylebox_override("panel", _cell_style)


func _run_trials() -> void:
	_logic = NBackLogic.new(_level, trials, _rng)
	_set_progress_text("%d-back   0 / %d" % [_level, trials])
	if not await _wait(1.0):
		return
	for i in trials:
		_current = i
		_cells[_logic.positions[i]].add_theme_stylebox_override("panel", _lit_style)
		_window_open = true
		if not await _wait(NBackLogic.STIMULUS_MS / 1000.0):
			return
		_cells[_logic.positions[i]].add_theme_stylebox_override("panel", _cell_style)
		if not await _wait((NBackLogic.INTERVAL_MS - NBackLogic.STIMULUS_MS) / 1000.0):
			return
		_window_open = false
		_logic.evaluate(i)
		_set_progress_text("%d-back   %d / %d" % [_level, i + 1, trials])
	_complete(_logic.build_result(definition.id, get_config()))


func _on_response() -> void:
	if not _running or not _window_open or _current < 0:
		return
	var hit := _logic.respond(_current)
	_flash_pad(_pad, get_theme_color("correct" if hit else "wrong_dim", "Pad"), 0.3)
