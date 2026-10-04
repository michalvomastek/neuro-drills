## Trail Making Test: click the nodes in order (1-2-3 or 1-A-2-B), as fast as possible.
extends TrialDrill

const NODE_SIZE := 0.1
const DRIFT_SPEEDS: Array[float] = [0.0, 0.06, 0.14]
const SPEED_LEVELS: Array[int] = [0, 1, 2]
const ORDER_KEYS: Array[String] = ["TRAIL_ORDER_NUM_ASC", "TRAIL_ORDER_NUM_DESC", "TRAIL_ORDER_NUM_ASC_LET_DESC", "TRAIL_ORDER_NUM_DESC_LET_ASC"]

var _order: TrailLogic.Order = TrailLogic.Order.NUMBERS_ASC
var _order_option: OptionButton
## Kinetic variant: 0 = still, 1 = slow drift, 2 = fast drift; nodes bounce off the edges.
var _speed: int = 0
var _speed_option: OptionButton
var _show_next: bool = true
var _show_next_check: CheckBox
var _show_timer: bool = false
var _show_timer_check: CheckBox
var _show_errors: bool = true
var _show_errors_check: CheckBox
var _velocities: Array[Vector2] = []
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
	_order_option = _add_labelled_option(parent, "TRAIL_ORDER", ORDER_KEYS)
	var speed_keys: Array[String] = ["TRAIL_SPEED_STILL", "TRAIL_SPEED_SLOW", "TRAIL_SPEED_FAST"]
	_speed_option = _add_labelled_option(parent, "TRAIL_SPEED", speed_keys)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	parent.add_child(grid)
	_show_next_check = CheckBox.new()
	_show_next_check.text = tr("SCHULTE_OPT_SHOW_NEXT")
	_show_next_check.button_pressed = _show_next
	grid.add_child(_show_next_check)
	_show_timer_check = CheckBox.new()
	_show_timer_check.text = tr("SCHULTE_OPT_SHOW_TIMER")
	grid.add_child(_show_timer_check)
	_show_errors_check = CheckBox.new()
	_show_errors_check.text = tr("TRAIL_OPT_SHOW_ERRORS")
	_show_errors_check.button_pressed = _show_errors
	grid.add_child(_show_errors_check)


## A labelled OptionButton whose items are translated keys with ids 0..n-1.
func _add_labelled_option(parent: VBoxContainer, label_key: String, item_keys: Array[String]) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var label := Label.new()
	label.text = tr(label_key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var option := OptionButton.new()
	for i in item_keys.size():
		option.add_item(tr(item_keys[i]), i)
	row.add_child(option)
	return option


func _apply_extra_config(config: Dictionary) -> void:
	var order_value: int = config.get("order", TrailLogic.Order.NUMBERS_ASC)
	if config.get("part_b", false) and not config.has("order"):
		order_value = TrailLogic.Order.NUMBERS_ASC_LETTERS_DESC
	_order = clampi(order_value, 0, ORDER_KEYS.size() - 1) as TrailLogic.Order
	var speed: int = config.get("speed", 1 if config.get("moving", false) else 0)
	_speed = clampi(speed, 0, DRIFT_SPEEDS.size() - 1)
	_show_next = config.get("show_next", true)
	_show_timer = config.get("show_timer", false)
	_show_errors = config.get("show_errors", true)
	_order_option.select(_order_option.get_item_index(_order))
	_speed_option.select(_speed_option.get_item_index(_speed))
	_show_next_check.button_pressed = _show_next
	_show_timer_check.button_pressed = _show_timer
	_show_errors_check.button_pressed = _show_errors


func _collect_extra_config() -> Dictionary:
	return {"order": _order, "speed": _speed, "show_next": _show_next, "show_timer": _show_timer, "show_errors": _show_errors}


func _on_start_pressed() -> void:
	_order = _order_option.get_selected_id() as TrailLogic.Order
	_speed = _speed_option.get_selected_id()
	_show_next = _show_next_check.button_pressed
	_show_timer = _show_timer_check.button_pressed
	_show_errors = _show_errors_check.button_pressed
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
	_logic = TrailLogic.new(trials, _order, _rng)
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
	_velocities.clear()
	for i in _logic.count:
		var angle := _rng.randf_range(0.0, TAU)
		_velocities.append(Vector2(cos(angle), sin(angle)) * DRIFT_SPEEDS[_speed])
	_layout_nodes()
	_started_at_ms = Time.get_ticks_msec()
	_update_status()


## Top-bar text: the symbol being searched for, the error count and the timer, as configured.
func _update_status() -> void:
	var parts: PackedStringArray = PackedStringArray()
	if _show_next and not _logic.finished:
		parts.append(tr("SCHULTE_NEXT_TARGET_TEXT") % _logic.labels[_logic.next_index])
	if _show_errors:
		parts.append(tr("SCHULTE_ERROR_COUNT") % _logic.error_count)
	if _show_timer:
		var elapsed := _logic.total_time_ms() if _logic.finished else Time.get_ticks_msec() - _started_at_ms
		parts.append(Format.seconds_short(elapsed))
	_set_progress_text("   ".join(parts))


func _process(delta: float) -> void:
	if not _running or _logic == null or _logic.finished:
		return
	if _show_timer:
		_update_status()
	if _speed == 0:
		return
	for i in _logic.positions.size():
		var p := _logic.positions[i] + _velocities[i] * delta
		if p.x < TrailLogic.MARGIN or p.x > 1.0 - TrailLogic.MARGIN:
			_velocities[i].x = -_velocities[i].x
		if p.y < TrailLogic.MARGIN or p.y > 1.0 - TrailLogic.MARGIN:
			_velocities[i].y = -_velocities[i].y
		_logic.positions[i] = p.clamp(Vector2.ONE * TrailLogic.MARGIN, Vector2.ONE * (1.0 - TrailLogic.MARGIN))
	# Keep nodes from overlapping: push close pairs apart and exchange their headings.
	for i in _logic.positions.size():
		for j in range(i + 1, _logic.positions.size()):
			var between := _logic.positions[j] - _logic.positions[i]
			var distance := between.length()
			if distance < NODE_SIZE * 1.1 and distance > 0.0:
				var normal := between / distance
				var push := (NODE_SIZE * 1.1 - distance) * 0.5
				_logic.positions[i] -= normal * push
				_logic.positions[j] += normal * push
				var swap := _velocities[i]
				_velocities[i] = _velocities[j]
				_velocities[j] = swap
	_layout_nodes()


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
		_update_status()
		if _logic.finished:
			_complete(_logic.build_result(definition.id, get_config()))
	else:
		_flash_pad(_nodes[index], get_theme_color("wrong", "Pad"), 0.4)
		_update_status()


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
