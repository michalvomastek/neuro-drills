## Drag-to-scroll for a ScrollContainer whose content is made of buttons.
##
## The engine's own touch scrolling needs a touchscreen the display server
## knows about and a press that reaches the container, which a button in the
## list swallows; on an iPhone in the browser the lists therefore moved only
## through the scrollbar. This node watches the pointer at the viewport level
## instead: a press inside the container arms it, a move beyond the deadzone
## scrolls the content and cancels the press of the control under the finger
## (NOTIFICATION_SCROLL_BEGIN, the same thing the engine sends), the release
## is swallowed and a short glide follows. Mouse drags scroll the same way.
## [method attach] is called for every ScrollContainer by the app shell.
class_name DragScroll
extends Node

const DEADZONE := 10.0
const GLIDE_FRICTION := 6.0
const MIN_GLIDE_SPEED := 20.0
const MAX_GLIDE_SPEED := 2500.0

var _scroll: ScrollContainer
var _armed: bool = false
var _dragging: bool = false
var _start: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _glide: Vector2 = Vector2.ZERO
var _remainder: Vector2 = Vector2.ZERO


static func attach(scroll: ScrollContainer) -> void:
	for child in scroll.get_children(true):
		if child is DragScroll:
			return
	var node := DragScroll.new()
	node._scroll = scroll
	scroll.add_child(node, false, Node.INTERNAL_MODE_BACK)


func _ready() -> void:
	set_process(false)


func _input(event: InputEvent) -> void:
	if _scroll == null or not _scroll.is_visible_in_tree():
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_try_arm(button.position)
		else:
			_release()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _armed:
		_move(motion.position, motion.relative)
		return
	# The touch events behind the emulated mouse events must not reach the
	# list while it is being dragged, or the engine's own handling joins in.
	if _dragging and (event is InputEventScreenDrag or event is InputEventScreenTouch):
		get_viewport().set_input_as_handled()


## Arms on a press inside the container, unless the press belongs to a
## nested ScrollContainer or to a control that drags on its own (slider, text).
func _try_arm(position: Vector2) -> void:
	if not _scroll.get_global_rect().has_point(position):
		return
	if not _can_scroll():
		return
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null:
		var node: Node = hovered
		while node != null and node != _scroll:
			if node is Range or node is LineEdit or node is TextEdit:
				return
			if node is ScrollContainer:
				return
			node = node.get_parent()
		if node == null:
			return
	_armed = true
	_dragging = false
	_start = position
	_velocity = Vector2.ZERO
	_glide = Vector2.ZERO
	_remainder = Vector2.ZERO
	set_process(false)


func _move(position: Vector2, relative: Vector2) -> void:
	if not _dragging:
		if position.distance_to(_start) < DEADZONE:
			return
		_dragging = true
		_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	_scroll_by(relative)
	var delta := maxf(get_process_delta_time(), 1.0 / 120.0)
	_velocity = _velocity.lerp(relative / delta, 0.5)
	get_viewport().set_input_as_handled()


func _release() -> void:
	if not _armed:
		return
	_armed = false
	if _dragging:
		_dragging = false
		_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_END)
		get_viewport().set_input_as_handled()
		_glide = _velocity.limit_length(MAX_GLIDE_SPEED)
		if _glide.length() > MIN_GLIDE_SPEED:
			set_process(true)


func _process(delta: float) -> void:
	_scroll_by(_glide * delta)
	_glide = _glide.lerp(Vector2.ZERO, clampf(GLIDE_FRICTION * delta, 0.0, 1.0))
	if _glide.length() < MIN_GLIDE_SPEED:
		set_process(false)


## Scrolls the content with the pointer; the scroll offsets are integers, so
## the fraction is carried over to the next move.
func _scroll_by(relative: Vector2) -> void:
	var scale := _scroll.get_global_transform().get_scale()
	var wanted := Vector2(relative.x / maxf(scale.x, 0.001), relative.y / maxf(scale.y, 0.001)) + _remainder
	var step := Vector2(roundf(wanted.x), roundf(wanted.y))
	_remainder = wanted - step
	if _scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_scroll.scroll_vertical -= int(step.y)
	if _scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_scroll.scroll_horizontal -= int(step.x)


func _can_scroll() -> bool:
	var v := _scroll.get_v_scroll_bar()
	var h := _scroll.get_h_scroll_bar()
	return (v != null and v.max_value > v.page) or (h != null and h.max_value > h.page)
