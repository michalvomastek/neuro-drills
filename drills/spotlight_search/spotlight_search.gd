## Spotlight search: find every T among the Ls, but you only see a small
## circle around the pointer. Move the mouse to scan the board.
extends TrialDrill

const SET_SIZE := 64
const TARGET_COUNT := 5
const RADII: Array[int] = [8, 12, 18]
const DEFAULT_RADIUS := 12

var _radius_percent: int = DEFAULT_RADIUS
var _radius_option: OptionButton
var _logic: SpotlightLogic
var _board: Control
var _grid: GridContainer
var _cells: Array[Button] = []
var _fog: ColorRect
var _material: ShaderMaterial
var _started_ms: int = 0
var _accepting: bool = false


func _uses_trial_count() -> bool:
	return false


func _build_extras(parent: VBoxContainer) -> void:
	_radius_option = _add_option_row(parent, "SPOTLIGHT_RADIUS", RADII, _radius_percent)


func _apply_extra_config(config: Dictionary) -> void:
	var requested: int = config.get("radius", DEFAULT_RADIUS)
	if RADII.has(requested):
		_radius_percent = requested
	_radius_option.select(_radius_option.get_item_index(_radius_percent))


func _collect_extra_config() -> Dictionary:
	return {"radius": _radius_percent}


func _on_start_pressed() -> void:
	_radius_percent = _radius_option.get_selected_id()
	super()


func _build_play_area(parent: Control) -> void:
	_board = _make_square_board(parent)
	_grid = GridContainer.new()
	_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grid.columns = 8
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_board.add_child(_grid)
	for i in SET_SIZE:
		var cell := _make_pad("", 30)
		cell.pressed.connect(_on_cell_pressed.bind(i))
		_grid.add_child(cell)
		_cells.append(cell)
	_fog = ColorRect.new()
	_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load("res://drills/spotlight_search/fog.gdshader") as Shader
	_fog.material = _material
	parent.add_child(_fog)
	_fog.resized.connect(_update_aspect)


func _update_aspect() -> void:
	_material.set_shader_parameter("aspect", _fog.size.x / maxf(1.0, _fog.size.y))
	_material.set_shader_parameter("spot_radius", _radius_percent / 100.0)


func _process(_delta: float) -> void:
	if not _running:
		return
	var local := _fog.get_local_mouse_position()
	_material.set_shader_parameter("spot_center", local / _fog.size)


func _run_trials() -> void:
	_logic = SpotlightLogic.new(SET_SIZE, TARGET_COUNT, _rng)
	_update_aspect()
	for i in _cells.size():
		_cells[i].text = _logic.letter_at(i)
		_clear_pad_flash(_cells[i])
	_set_progress_text("0 / %d" % TARGET_COUNT)
	_started_ms = Time.get_ticks_msec()
	_accepting = true


func _on_cell_pressed(index: int) -> void:
	if not _running or not _accepting:
		return
	if _logic.click(index, Time.get_ticks_msec() - _started_ms):
		_set_pad_color(_cells[index], get_theme_color("correct", "Pad"))
		_set_progress_text("%d / %d" % [_logic.found.size(), TARGET_COUNT])
		if _logic.is_done():
			_accepting = false
			_complete(_logic.build_result(definition.id, get_config()))
	else:
		_flash_pad(_cells[index], get_theme_color("wrong", "Pad"), 0.3)
