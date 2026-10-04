## Schulte table scene: setup panel, optional countdown, the clickable grid and
## hand-off of the result. All rules live in SchulteLogic.
extends Drill

const CELL_FONT_RATIO := 0.42
const MIN_CELL_FONT_SIZE := 12
const FLASH_HOLD_SECONDS := 0.12
const FLASH_FADE_SECONDS := 0.45
const COUNTER_PULSE_SECONDS := 0.5
const FLASH_STATES: Array[StringName] = [&"normal", &"hover", &"pressed"]
const COUNTDOWN_FROM := 3
const DIM_FOUND_ALPHA := 0.3

@onready var _setup_panel: Control = %SetupPanel
@onready var _grid_size_option: OptionButton = %GridSizeOption
@onready var _countdown_check: CheckBox = %CountdownCheck
@onready var _fixation_check: CheckBox = %FixationCheck
@onready var _show_next_check: CheckBox = %ShowNextCheck
@onready var _dim_found_check: CheckBox = %DimFoundCheck
@onready var _show_errors_check: CheckBox = %ShowErrorsCheck
@onready var _highlight_correct_check: CheckBox = %HighlightCorrectCheck
@onready var _show_timer_check: CheckBox = %ShowTimerCheck
@onready var _start_button: Button = %StartButton
@onready var _setup_back_button: Button = %SetupBackButton
@onready var _play_panel: Control = %PlayPanel
@onready var _play_back_button: Button = %PlayBackButton
@onready var _next_target_label: Label = %NextTargetLabel
@onready var _error_count_label: Label = %ErrorCountLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _grid: GridContainer = %Grid
@onready var _fixation_dot: Control = %FixationDot
@onready var _countdown_panel: Control = %CountdownPanel
@onready var _countdown_label: Label = %CountdownLabel

var _config := SchulteConfig.new()
var _logic: SchulteLogic
var _cells: Array[Button] = []
var _started_at_ms: int = 0
## True between the grid appearing and the last correct click.
var _running: bool = false
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


func _process(_delta: float) -> void:
	if _running and _config.show_timer:
		_timer_label.text = Format.seconds_short(Time.get_ticks_msec() - _started_at_ms)


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
	_show_errors_check.button_pressed = _config.show_errors
	_highlight_correct_check.button_pressed = _config.highlight_correct
	_show_timer_check.button_pressed = _config.show_timer


func _read_config_from_controls() -> SchulteConfig:
	var config := SchulteConfig.new()
	config.grid_size = _grid_size_option.get_selected_id()
	config.countdown = _countdown_check.button_pressed
	config.fixation_dot = _fixation_check.button_pressed
	config.show_next_target = _show_next_check.button_pressed
	config.dim_found = _dim_found_check.button_pressed
	config.show_errors = _show_errors_check.button_pressed
	config.highlight_correct = _highlight_correct_check.button_pressed
	config.show_timer = _show_timer_check.button_pressed
	return config


func _show_setup() -> void:
	_run_token += 1
	_running = false
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
	_running = false
	_setup_panel.visible = false
	_play_panel.visible = false
	_build_grid()
	if _config.countdown:
		# Only the countdown is on screen; the play panel (with its Back button) follows it.
		_countdown_panel.visible = true
		for i in range(COUNTDOWN_FROM, 0, -1):
			_countdown_label.text = str(i)
			await get_tree().create_timer(1.0).timeout
			if token != _run_token or not is_inside_tree():
				return
		_countdown_panel.visible = false
	_play_panel.visible = true
	_grid.visible = true
	_fixation_dot.visible = _config.fixation_dot
	_started_at_ms = Time.get_ticks_msec()
	_running = true
	_timer_label.visible = _config.show_timer
	_timer_label.text = Format.seconds_short(0)
	_update_next_target()
	_update_error_count()


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
		# Fire on press, not on release: faster and feels more direct.
		cell.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
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
	if _logic == null or not _running:
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
			if _config.show_errors:
				_flash_cell(_cells[index], get_theme_color("wrong_flash", "SchulteCell"))
				_update_error_count()
				_pulse_label(_error_count_label, get_theme_color("wrong_flash", "SchulteCell"))


func _mark_found(cell: Button) -> void:
	if _config.highlight_correct:
		_flash_cell(cell, get_theme_color("correct_flash", "SchulteCell"))
	if _config.dim_found:
		cell.modulate.a = DIM_FOUND_ALPHA


## Fills the cell with [param color] in every drawn state (the pointer still
## hovers the cell after a click) and fades it back to the cell's own colour.
func _flash_cell(cell: Button, color: Color) -> void:
	_kill_tween_meta(cell, &"flash_tween")
	var base := get_theme_stylebox("normal", "SchulteCell") as StyleBoxFlat
	var style := base.duplicate() as StyleBoxFlat
	style.bg_color = color
	for state in FLASH_STATES:
		cell.add_theme_stylebox_override(state, style)
	var tween := cell.create_tween()
	tween.tween_property(style, "bg_color", base.bg_color, FLASH_FADE_SECONDS).set_delay(FLASH_HOLD_SECONDS)
	tween.tween_callback(_clear_flash.bind(cell))
	cell.set_meta("flash_tween", tween)


## Stops a still-running tween stored in [param key] so a new one can take over.
func _kill_tween_meta(node: Node, key: StringName) -> void:
	if not node.has_meta(key):
		return
	var previous: Tween = node.get_meta(key)
	if previous != null and previous.is_valid():
		previous.kill()


func _clear_flash(cell: Button) -> void:
	for state in FLASH_STATES:
		cell.remove_theme_stylebox_override(state)


func _pulse_label(label: Label, color: Color) -> void:
	_kill_tween_meta(label, &"pulse_tween")
	label.add_theme_color_override("font_color", color)
	var tween := label.create_tween()
	tween.tween_property(label, "theme_override_colors/font_color", get_theme_color("font_color", "Label"), COUNTER_PULSE_SECONDS)
	tween.tween_callback(label.remove_theme_color_override.bind("font_color"))
	label.set_meta("pulse_tween", tween)


func _update_error_count() -> void:
	_error_count_label.visible = _config.show_errors
	_error_count_label.text = tr("SCHULTE_ERROR_COUNT") % _logic.error_count


func _update_next_target() -> void:
	_next_target_label.visible = _config.show_next_target
	_next_target_label.text = tr("SCHULTE_NEXT_TARGET") % _logic.next_target


func _finish() -> void:
	_run_token += 1
	_running = false
	if _config.show_timer:
		_timer_label.text = Format.seconds_short(_logic.total_time_ms())
	finished.emit(_logic.build_result(definition.id, _config.to_dict()))
