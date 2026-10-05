## A drop-down replacement for long lists on touch screens. The engine's
## PopupMenu activates the item under the finger when a drag ends, so this
## button opens a panel with a scrollable list of buttons instead: the list
## scrolls by dragging (DragScroll), a tap picks. Mirrors the small part of
## the OptionButton API the screens use.
class_name ListPickButton
extends Button

signal item_selected(index: int)

const ARROW := "  ▾"
const MAX_PANEL_WIDTH := 440.0
const ITEM_HEIGHT := 48.0

## Index of the selected item, -1 for none.
var selected: int = -1:
	set(value):
		selected = value
		_refresh_text()
var item_count: int:
	get:
		return _items.size()

var _items: PackedStringArray = PackedStringArray()
var _metadata: Array = []
var _popup: PopupPanel


func _ready() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	clip_text = true
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pressed.connect(_open)
	_refresh_text()


func add_item(label: String) -> void:
	_items.append(label)
	_metadata.append(null)
	if selected < 0:
		selected = 0
	else:
		_refresh_text()


func set_item_metadata(index: int, metadata: Variant) -> void:
	_metadata[index] = metadata


func get_item_metadata(index: int) -> Variant:
	return _metadata[index]


func get_item_text(index: int) -> String:
	return _items[index]


func clear() -> void:
	_items.clear()
	_metadata.clear()
	selected = -1


func select(index: int) -> void:
	selected = clampi(index, -1, _items.size() - 1)


func _refresh_text() -> void:
	text = (_items[selected] if selected >= 0 and selected < _items.size() else "") + ARROW


## A panel under the button (or centred when it would not fit) with one
## button per item; the current item is highlighted.
func _open() -> void:
	if _items.is_empty():
		return
	if _popup != null:
		_popup.queue_free()
	_popup = PopupPanel.new()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_popup.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	var current: Button = null
	for i in _items.size():
		var button := Button.new()
		button.text = _items[i]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.theme_type_variation = &"PrimaryButton" if i == selected else &"SmallButton"
		button.pressed.connect(_on_item_pressed.bind(i))
		list.add_child(button)
		if i == selected:
			current = button
	add_child(_popup)
	var viewport_size := get_viewport_rect().size
	var width := minf(maxf(size.x, 260.0), minf(MAX_PANEL_WIDTH, viewport_size.x - 24.0))
	var height := minf(_items.size() * (ITEM_HEIGHT + 4.0) + 16.0, viewport_size.y * 0.6)
	var rect := Rect2(global_position + Vector2(0, size.y + 4.0), Vector2(width, height))
	if rect.end.y > viewport_size.y - 8.0:
		rect.position.y = maxf(8.0, global_position.y - height - 4.0)
	rect.position.x = clampf(rect.position.x, 8.0, maxf(8.0, viewport_size.x - width - 8.0))
	_popup.popup(rect)
	if current != null:
		scroll.ensure_control_visible.call_deferred(current)


func _on_item_pressed(index: int) -> void:
	_popup.hide()
	if index != selected:
		selected = index
		item_selected.emit(index)
