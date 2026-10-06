## Sum pairs: tap two numbers that add up to the target and see each other
## along a clear row, column or diagonal; they vanish and new numbers appear
## elsewhere. Timed run; options: grid size, target, a target that changes
## after every pair, and chains of several numbers.
extends TrialDrill

const DURATIONS: Array[int] = [30, 60, 90]
const DEFAULT_DURATION := 60
const SIZES: Array[int] = [4, 5, 6]
const DEFAULT_SIZE := 5
const TARGETS: Array[int] = [8, 10, 12]
const DEFAULT_TARGET := 10
const LINE_WIDTH := 6.0
const LINE_FADE_SECONDS := 0.35

var _duration: int = DEFAULT_DURATION
var _size: int = DEFAULT_SIZE
var _target: int = DEFAULT_TARGET
var _dynamic: bool = false
var _chains: bool = false
var _duration_option: OptionButton
var _size_option: OptionButton
var _target_option: OptionButton
var _dynamic_check: CheckBox
var _chains_check: CheckBox
var _logic: SumPairsLogic
var _target_label: Label
var _board: Control
var _grid: GridContainer
var _lines: Control
var _cells: Array[Button] = []
var _started_ms: int = 0
var _ends_at_ms: int = 0
var _accepting: bool = false
## The last completed path, drawn while it fades out.
var _fading_path: Array[int] = []
var _fade: float = 0.0
var _fade_tween: Tween
var _shown_tenths: int = -1
var _shown_completed: int = -1


func _uses_trial_count() -> bool:
	return false


func _build_extras(parent: VBoxContainer) -> void:
	_duration_option = _add_option_row(parent, "SUMPAIRS_DURATION", DURATIONS, _duration)
	_size_option = _add_option_row(parent, "SUMPAIRS_GRID", SIZES, _size)
	_target_option = _add_option_row(parent, "SUMPAIRS_TARGET", TARGETS, _target)
	_dynamic_check = CheckBox.new()
	_dynamic_check.text = tr("SUMPAIRS_OPT_DYNAMIC")
	parent.add_child(_dynamic_check)
	_chains_check = CheckBox.new()
	_chains_check.text = tr("SUMPAIRS_OPT_CHAINS")
	parent.add_child(_chains_check)
	_dynamic_check.toggled.connect(func(on: bool) -> void: _target_option.disabled = on)


func _apply_extra_config(config: Dictionary) -> void:
	var duration: int = config.get("duration_s", DEFAULT_DURATION)
	if DURATIONS.has(duration):
		_duration = duration
	var grid_size: int = config.get("size", DEFAULT_SIZE)
	if SIZES.has(grid_size):
		_size = grid_size
	var target: int = config.get("target", DEFAULT_TARGET)
	if TARGETS.has(target):
		_target = target
	_dynamic = config.get("dynamic", false)
	_chains = config.get("chains", false)
	_duration_option.select(_duration_option.get_item_index(_duration))
	_size_option.select(_size_option.get_item_index(_size))
	_target_option.select(_target_option.get_item_index(_target))
	_dynamic_check.button_pressed = _dynamic
	_chains_check.button_pressed = _chains
	_target_option.disabled = _dynamic


## With a changing target the setup's target is only the seed of the first
## one, so it stays out of the config (and of the variant key).
func _collect_extra_config() -> Dictionary:
	var config := {"duration_s": _duration, "size": _size, "dynamic": _dynamic, "chains": _chains}
	if not _dynamic:
		config["target"] = _target
	return config


func _preview_extra_config() -> Dictionary:
	return {"size": _size_option.get_selected_id(), "dynamic": _dynamic_check.button_pressed, "chains": _chains_check.button_pressed}


func _on_start_pressed() -> void:
	_duration = _duration_option.get_selected_id()
	_size = _size_option.get_selected_id()
	_target = _target_option.get_selected_id()
	_dynamic = _dynamic_check.button_pressed
	_chains = _chains_check.button_pressed
	super()


func _build_play_area(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	parent.add_child(vbox)
	_target_label = Label.new()
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_label.theme_type_variation = &"StimulusLabel"
	_target_label.add_theme_font_size_override("font_size", 40)
	vbox.add_child(_target_label)
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(stage)
	_board = _make_square_board(stage)
	_grid = GridContainer.new()
	_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_board.add_child(_grid)
	_lines = Control.new()
	_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.draw.connect(_draw_lines)
	_board.add_child(_lines)
	_build_cells()


## The grid is rebuilt when the size changes between runs.
func _build_cells() -> void:
	for cell in _cells:
		cell.queue_free()
	_cells.clear()
	_grid.columns = _size
	var font_size := 40 if _size <= 4 else (36 if _size == 5 else 30)
	for i in _size * _size:
		var cell := _make_pad("", font_size)
		cell.pressed.connect(_on_cell_pressed.bind(i))
		_grid.add_child(cell)
		_cells.append(cell)


func _reset_play_state() -> void:
	_accepting = false
	_fading_path.clear()
	_fade = 0.0
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null
	for cell in _cells:
		_clear_pad_flash(cell)
	if _lines != null:
		_lines.queue_redraw()


func _process(_delta: float) -> void:
	if not _accepting:
		return
	# One decimal is shown, so the label only changes ten times a second.
	var tenths := maxi(0, _ends_at_ms - Time.get_ticks_msec()) / 100
	if tenths != _shown_tenths or _logic.completed != _shown_completed:
		_shown_tenths = tenths
		_shown_completed = _logic.completed
		_set_progress_text("%s   %d" % [Format.seconds_short(tenths * 100), _logic.completed])


func _run_trials() -> void:
	if _cells.size() != _size * _size:
		_build_cells()
	_logic = SumPairsLogic.new(_size, _target, _dynamic, _chains, _rng)
	_render()
	_started_ms = Time.get_ticks_msec()
	_ends_at_ms = _started_ms + _duration * 1000
	_accepting = true
	if not await _wait(_duration):
		return
	_accepting = false
	_complete(_logic.build_result(definition.id, get_config(), _duration * 1000))


func _render() -> void:
	_target_label.text = tr("SUMPAIRS_TARGET_LABEL") % _logic.target
	for i in _cells.size():
		var value := _logic.value_at(i)
		var cell := _cells[i]
		cell.text = str(value) if value > 0 else ""
		# An empty cell stays a live button (a tap on it is ignored by the
		# logic) so the completion flash can still colour it.
		cell.modulate.a = 1.0 if value > 0 else 0.0
		if _logic.is_selected(i):
			_set_pad_color(cell, get_theme_color("primary", "App"))
		else:
			_clear_pad_flash(cell)
	_lines.queue_redraw()


func _on_cell_pressed(index: int) -> void:
	if not _running or not _accepting:
		return
	var selected_before: Array[int] = _logic.selection.duplicate()
	var outcome := _logic.tap(index, Time.get_ticks_msec() - _started_ms)
	match outcome:
		SumPairsLogic.Outcome.COMPLETED:
			selected_before.append(index)
			_show_completed(selected_before)
		SumPairsLogic.Outcome.BLOCKED, SumPairsLogic.Outcome.WRONG_SUM:
			selected_before.append(index)
			_render()
			for cell in selected_before:
				_flash_pad(_cells[cell], get_theme_color("wrong", "Pad"), 0.35)
		SumPairsLogic.Outcome.IGNORED:
			return
		_:
			_render()


## Shows the refilled board at once (the new numbers sit elsewhere) and lets
## the removed cells flash green under a fading line; the tween, which
## _reset_play_state() kills, hides them again at the end.
func _show_completed(path: Array[int]) -> void:
	_render()
	_fading_path = path
	_fade = 1.0
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_method(_set_fade, 1.0, 0.0, LINE_FADE_SECONDS)
	_fade_tween.tween_callback(_render)
	for cell in path:
		var pad := _cells[cell]
		pad.modulate.a = 1.0
		_flash_pad(pad, get_theme_color("correct", "Pad"), LINE_FADE_SECONDS)


func _set_fade(value: float) -> void:
	_fade = value
	_lines.queue_redraw()


func _cell_centre(cell: int) -> Vector2:
	return _cells[cell].get_global_rect().get_center() - _lines.get_global_rect().position


func _draw_lines() -> void:
	if _logic == null or _cells.is_empty():
		return
	var ink := get_theme_color("primary", "App")
	for i in range(1, _logic.selection.size()):
		_lines.draw_line(_cell_centre(_logic.selection[i - 1]), _cell_centre(_logic.selection[i]), ink, LINE_WIDTH, true)
	if _fade > 0.0 and _fading_path.size() > 1:
		var green := get_theme_color("green", "App")
		green.a = _fade
		for i in range(1, _fading_path.size()):
			_lines.draw_line(_cell_centre(_fading_path[i - 1]), _cell_centre(_fading_path[i]), green, LINE_WIDTH, true)
