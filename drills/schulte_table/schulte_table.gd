## Schulte table scene: setup panel, optional countdown, the clickable grid and
## hand-off of the result. All rules live in SchulteLogic.
extends Drill

const CELL_FONT_RATIO := 0.42
const MIN_CELL_FONT_SIZE := 12
const WRONG_FLASH_SECONDS := 0.18
const COUNTDOWN_FROM := 3
const DIM_FOUND_ALPHA := 0.3

@onready var _setup_panel: Control = %SetupPanel
@onready var _grid_size_option: OptionButton = %GridSizeOption
@onready var _countdown_check: CheckBox = %CountdownCheck
@onready var _fixation_check: CheckBox = %FixationCheck
@onready var _show_next_check: CheckBox = %ShowNextCheck
@onready var _dim_found_check: CheckBox = %DimFoundCheck
@onready var _start_button: Button = %StartButton
@onready var _setup_back_button: Button = %SetupBackButton
@onready var _play_panel: Control = %PlayPanel
@onready var _play_back_button: Button = %PlayBackButton
@onready var _next_target_label: Label = %NextTargetLabel
@onready var _grid: GridContainer = %Grid
@onready var _fixation_dot: Control = %FixationDot
@onready var _countdown_panel: Control = %CountdownPanel
@onready var _countdown_label: Label = %CountdownLabel

var _config := SchulteConfig.new()
var _logic: SchulteLogic
var _cells: Array[Button] = []
var _started_at_ms: int = 0
## Incremented whenever a run starts or stops so stale countdowns bail out.
var _run_token: int = 0


func _ready() -> void:
	for size in range(SchulteConfig.MIN_GRID_SIZE, SchulteConfig.MAX_GRID_SIZE + 1):
		_grid_size_option.add_item("%d × %d" % [size, size], size)
	_start_button.pressed.connect(_on_start_pressed)
	_setup_back_button.pressed.connect(_on_setup_back_pressed)
	_play_back_button.pressed.connect(_on_play_back_pressed)
	_grid.resized.connect(_update_cell_font_size)
	_apply_config_to_controls()
	_show_setup()


func _on_setup(config: Dictionary, autostart: bool) -> void:
	_config = SchulteConfig.from_dict(config)
	_apply_config_to_controls()
	if autostart:
		_begin_run()
	else:
		_show_setup()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _play_panel.visible or _countdown_panel.visible:
			_on_play_back_pressed()
		else:
			_on_setup_back_pressed()
		get_viewport().set_input_as_handled()


func _apply_config_to_controls() -> void:
	_grid_size_option.select(_grid_size_option.get_item_index(_config.grid_size))
	_countdown_check.button_pressed = _config.countdown
	_fixation_check.button_pressed = _config.fixation_dot
	_show_next_check.button_pressed = _config.show_next_target
	_dim_found_check.button_pressed = _config.dim_found


func _read_config_from_controls() -> SchulteConfig:
	var config := SchulteConfig.new()
	config.grid_size = _grid_size_option.get_selected_id()
	config.countdown = _countdown_check.button_pressed
	config.fixation_dot = _fixation_check.button_pressed
	config.show_next_target = _show_next_check.button_pressed
	config.dim_found = _dim_found_check.button_pressed
	return config


func _show_setup() -> void:
	_run_token += 1
	_setup_panel.visible = true
	_play_panel.visible = false
	_countdown_panel.visible = false
	_start_button.grab_focus()


func _on_start_pressed() -> void:
	_config = _read_config_from_controls()
	_begin_run()


func _on_setup_back_pressed() -> void:
	aborted.emit()


func _on_play_back_pressed() -> void:
	_show_setup()


func _begin_run() -> void:
	_run_token += 1
	var token := _run_token
	_setup_panel.visible = false
	_build_grid()
	_play_panel.visible = true
	_grid.visible = false
	_fixation_dot.visible = false
	_next_target_label.visible = false
	if _config.countdown:
		_countdown_panel.visible = true
		for i in range(COUNTDOWN_FROM, 0, -1):
			_countdown_label.text = str(i)
			await get_tree().create_timer(1.0).timeout
			if token != _run_token or not is_inside_tree():
				return
		_countdown_panel.visible = false
	_grid.visible = true
	_fixation_dot.visible = _config.fixation_dot
	_started_at_ms = Time.get_ticks_msec()
	_update_next_target()


func _build_grid() -> void:
	for cell in _cells:
		cell.queue_free()
	_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_logic = SchulteLogic.new(_config.grid_size, rng)
	_grid.columns = _config.grid_size
	for index in _logic.cells.size():
		var cell := Button.new()
		cell.text = str(_logic.cells[index])
		cell.theme_type_variation = &"SchulteCell"
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.focus_mode = Control.FOCUS_NONE
		cell.pressed.connect(_on_cell_pressed.bind(index))
		_grid.add_child(cell)
		_cells.append(cell)
	_update_cell_font_size()


func _update_cell_font_size() -> void:
	if _cells.is_empty():
		return
	var cell_height := _grid.size.y / _config.grid_size
	var font_size := maxi(MIN_CELL_FONT_SIZE, int(cell_height * CELL_FONT_RATIO))
	for cell in _cells:
		cell.add_theme_font_size_override("font_size", font_size)


func _on_cell_pressed(index: int) -> void:
	if _logic == null or not _grid.visible:
		return
	var elapsed := Time.get_ticks_msec() - _started_at_ms
	match _logic.register_click(index, elapsed):
		SchulteLogic.ClickOutcome.CORRECT:
			_mark_found(_cells[index])
			_update_next_target()
		SchulteLogic.ClickOutcome.COMPLETED:
			_mark_found(_cells[index])
			_finish()
		SchulteLogic.ClickOutcome.WRONG:
			_flash_wrong(_cells[index])


func _mark_found(cell: Button) -> void:
	if _config.dim_found:
		cell.modulate.a = DIM_FOUND_ALPHA


func _flash_wrong(cell: Button) -> void:
	cell.add_theme_stylebox_override("normal", get_theme_stylebox("wrong", "SchulteCell"))
	await get_tree().create_timer(WRONG_FLASH_SECONDS).timeout
	if is_instance_valid(cell):
		cell.remove_theme_stylebox_override("normal")


func _update_next_target() -> void:
	_next_target_label.visible = _config.show_next_target
	_next_target_label.text = tr("SCHULTE_NEXT_TARGET") % _logic.next_target


func _finish() -> void:
	_run_token += 1
	finished.emit(_logic.build_result(definition.id, _config.to_dict()))
