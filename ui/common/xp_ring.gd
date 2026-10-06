## The player's level inside a ring whose arc shows the progress to the
## next level; used by the top bar. Colours come from the theme so the ring
## works on both backgrounds.
class_name XpRing
extends Control

const DIAMETER := 38.0
const THICKNESS := 3.5

var _ratio: float = 0.0
var _label: Label


func _init() -> void:
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.theme_type_variation = &"PillLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func set_level(level: int, into: int, span: int) -> void:
	_label.text = str(level)
	_label.add_theme_color_override("font_color", get_theme_color("text", "App"))
	_ratio = clampf(float(into) / maxf(float(span), 1.0), 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - THICKNESS * 0.5
	draw_arc(centre, radius, 0.0, TAU, 64, get_theme_color("line", "App"), THICKNESS, true)
	if _ratio > 0.0:
		draw_arc(centre, radius, -PI / 2.0, -PI / 2.0 + TAU * _ratio, 64, get_theme_color("accent", "App"), THICKNESS, true)
