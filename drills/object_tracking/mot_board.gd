## Draws the discs of a MotLogic and reports clicks on them.
class_name MotBoard
extends Control

signal disc_clicked(index: int)

var logic: MotLogic
var highlight_targets: bool = false
var show_selection: bool = false
var reveal: bool = false
var base_color := Color(0.6, 0.63, 0.7)
var target_color := Color(0.35, 0.62, 1.0)
var selected_color := Color(0.95, 0.8, 0.3)
var correct_color := Color(0.18, 0.6, 0.32)
var wrong_color := Color(0.78, 0.2, 0.2)


func _draw() -> void:
	if logic == null:
		return
	var side := minf(size.x, size.y)
	var origin := (size - Vector2(side, side)) * 0.5
	for i in logic.positions.size():
		var color := base_color
		var is_target := logic.targets.has(i)
		var is_selected := logic.selected.has(i)
		if highlight_targets and is_target:
			color = target_color
		elif reveal and is_selected:
			color = correct_color if is_target else wrong_color
		elif reveal and is_target:
			color = target_color
		elif show_selection and is_selected:
			color = selected_color
		draw_circle(origin + logic.positions[i] * side, MotLogic.RADIUS * side, color)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT or logic == null:
		return
	var side := minf(size.x, size.y)
	var origin := (size - Vector2(side, side)) * 0.5
	var index := logic.ball_at((button.position - origin) / side)
	if index >= 0:
		disc_clicked.emit(index)
		accept_event()
