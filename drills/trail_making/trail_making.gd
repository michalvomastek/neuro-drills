## Trail Making Test: click the nodes in order (1-2-3 or 1-A-2-B), as fast as possible.
extends TrialDrill

const NODE_SIZE := 0.1

var _part_b: bool = false
var _part_b_check: CheckBox
var _logic: TrailLogic
var _board: Control
var _lines: TrailLines
var _nodes: Array[Button] = []
var _started_at_ms: int = 0
var _circle_style: StyleBoxFlat


func _trial_options() -> Array[int]:
	return [10, 16, 20]


func _default_trials() -> int:
	return 16


func _build_extras(parent: VBoxContainer) -> void:
	_part_b_check = CheckBox.new()
	_part_b_check.text = tr("TRAIL_OPT_PART_B")
	parent.add_child(_part_b_check)


func _apply_extra_config(config: Dictionary) -> void:
	_part_b = config.get("part_b", false)
	_part_b_check.button_pressed = _part_b


func _collect_extra_config() -> Dictionary:
	return {"part_b": _part_b}


func _on_start_pressed() -> void:
	_part_b = _part_b_check.button_pressed
	super()


func _build_play_area(parent: Control) -> void:
	_board = _make_square_board(parent)
	_board.resized.connect(_layout_nodes)
	_lines = TrailLines.new()
	_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(_lines)
	_circle_style = (get_theme_stylebox("normal", "Pad") as StyleBoxFlat).duplicate() as StyleBoxFlat
	_circle_style.set_corner_radius_all(200)
	_circle_style.bg_color = get_theme_color("cell", "Board")


func _run_trials() -> void:
	_logic = TrailLogic.new(trials, _part_b, _rng)
	for node in _nodes:
		node.queue_free()
	_nodes.clear()
	_lines.set_points(PackedVector2Array())
	for i in _logic.count:
		var node := _make_pad(_logic.labels[i], 28)
		for state in PAD_STATES:
			node.add_theme_stylebox_override(state, _circle_style)
		node.pressed.connect(_on_node_pressed.bind(i))
		_board.add_child(node)
		_nodes.append(node)
	_layout_nodes()
	_set_progress_text(tr("SCHULTE_NEXT_TARGET") % 1 if not _part_b else "1")
	_started_at_ms = Time.get_ticks_msec()


func _layout_nodes() -> void:
	if _nodes.is_empty():
		return
	var side := minf(_board.size.x, _board.size.y)
	var node_px := NODE_SIZE * side
	for i in _nodes.size():
		_nodes[i].size = Vector2(node_px, node_px)
		_nodes[i].position = _logic.positions[i] * side - Vector2(node_px, node_px) * 0.5
		_nodes[i].add_theme_font_size_override("font_size", maxi(12, int(node_px * 0.42)))
	_update_lines()


func _update_lines() -> void:
	var points := PackedVector2Array()
	var side := minf(_board.size.x, _board.size.y)
	for i in _logic.next_index:
		points.append(_logic.positions[i] * side)
	_lines.set_points(points)


func _on_node_pressed(index: int) -> void:
	if not _running or _logic.finished:
		return
	var correct := _logic.register_click(index, Time.get_ticks_msec() - _started_at_ms)
	if correct:
		_set_pad_color(_nodes[index], get_theme_color("lit", "Board"))
		_update_lines()
		if _logic.finished:
			_complete(_logic.build_result(definition.id, get_config()))
		else:
			_set_progress_text(_logic.labels[_logic.next_index])
	else:
		_flash_pad(_nodes[index], get_theme_color("wrong", "Pad"), 0.4)


func _set_pad_color(pad: Button, color: Color) -> StyleBoxFlat:
	var style := _circle_style.duplicate() as StyleBoxFlat
	style.bg_color = color
	for state in PAD_STATES:
		pad.add_theme_stylebox_override(state, style)
	return style


func _flash_pad(pad: Button, color: Color, fade_seconds: float = 0.4) -> void:
	var style := _set_pad_color(pad, color)
	var tween := pad.create_tween()
	tween.tween_property(style, "bg_color", _circle_style.bg_color, fade_seconds)
	tween.tween_callback(_restore_circle.bind(pad))


func _restore_circle(pad: Button) -> void:
	for state in PAD_STATES:
		pad.add_theme_stylebox_override(state, _circle_style)
