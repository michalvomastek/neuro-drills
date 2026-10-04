## Draws a polyomino centred in its rect.
class_name PolyominoView
extends Control

var cells: Array[Vector2i] = []
var color := Color(0.93, 0.93, 0.95):
	set(value):
		color = value
		_color_set = true
		queue_redraw()
var _color_set := false


func set_cells(new_cells: Array[Vector2i]) -> void:
	cells = new_cells
	queue_redraw()


## Draws with the theme ink unless a colour was assigned.
func _ready() -> void:
	if not _color_set:
		color = get_theme_color("ink", "Board")


func _draw() -> void:
	if cells.is_empty():
		return
	var max_x := 0
	var max_y := 0
	for c in cells:
		max_x = maxi(max_x, c.x)
		max_y = maxi(max_y, c.y)
	var unit := minf(size.x / 5.0, size.y / 5.0)
	var origin := (size - Vector2(max_x + 1, max_y + 1) * unit) * 0.5
	for c in cells:
		draw_rect(Rect2(origin + Vector2(c) * unit + Vector2(2, 2), Vector2(unit - 4, unit - 4)), color)
