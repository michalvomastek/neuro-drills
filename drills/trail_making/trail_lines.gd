## Draws the path through the nodes connected so far.
class_name TrailLines
extends Control

var points := PackedVector2Array()
var color := Color(0.35, 0.62, 1.0, 0.8)


func set_points(new_points: PackedVector2Array) -> void:
	points = new_points
	queue_redraw()


func _draw() -> void:
	if points.size() >= 2:
		draw_polyline(points, color, 4.0, true)
