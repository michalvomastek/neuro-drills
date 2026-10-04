## Draws a Landolt C: a ring with a gap on one side.
class_name LandoltRing
extends Control

var gap: int = 0
var color := Color(0.93, 0.93, 0.95)


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5
	var centre := size * 0.5
	var thickness := radius * 0.4
	var gap_angle := deg_to_rad(28.0)
	# Gap enum order UP, RIGHT, DOWN, LEFT maps to -90, 0, 90, 180 degrees.
	var gap_centre := deg_to_rad(-90.0 + 90.0 * gap)
	draw_arc(centre, radius - thickness * 0.5, gap_centre + gap_angle * 0.5, gap_centre + TAU - gap_angle * 0.5, 48, color, thickness, true)
