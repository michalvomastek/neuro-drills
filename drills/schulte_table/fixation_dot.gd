## Small dot drawn in the centre of its rect; overlays the grid as a gaze anchor.
extends Control

const RADIUS := 5.0

@export var color: Color = Color(0.35, 0.66, 1.0)


func _draw() -> void:
	draw_circle(size * 0.5, RADIUS, color)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
