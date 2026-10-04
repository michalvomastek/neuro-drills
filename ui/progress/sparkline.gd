## Tiny line chart of the last runs of one variant. Better is always up: when
## lower is better the axis is flipped. The best run is marked.
class_name Sparkline
extends Control

var values: PackedFloat64Array = PackedFloat64Array():
	set(v):
		values = v
		queue_redraw()
var lower_is_better: bool = true:
	set(v):
		lower_is_better = v
		queue_redraw()

const PADDING := 10.0
const POINT_RADIUS := 4.0


func _draw() -> void:
	var dim := get_theme_color("font_color", "DimLabel")
	var accent := get_theme_color("lit", "Board")
	var best_color := get_theme_color("correct", "Pad")
	var rect := Rect2(Vector2(PADDING, PADDING), size - Vector2(PADDING * 2.0, PADDING * 2.0))
	draw_line(rect.position + Vector2(0, rect.size.y), rect.end, dim * Color(1, 1, 1, 0.5), 1.0)
	if values.is_empty():
		return
	var low := values[0]
	var high := values[0]
	for v in values:
		low = minf(low, v)
		high = maxf(high, v)
	var span := maxf(high - low, 0.000001)
	var points := PackedVector2Array()
	var best_index := 0
	for i in values.size():
		var x := rect.position.x + (rect.size.x * i / maxi(1, values.size() - 1) if values.size() > 1 else rect.size.x * 0.5)
		var t := (values[i] - low) / span
		if lower_is_better:
			t = 1.0 - t
		var y := rect.position.y + rect.size.y * (1.0 - t)
		points.append(Vector2(x, y))
		var better := values[i] < values[best_index] if lower_is_better else values[i] > values[best_index]
		if better:
			best_index = i
	if points.size() > 1:
		draw_polyline(points, accent, 2.0, true)
	for i in points.size():
		draw_circle(points[i], POINT_RADIUS, best_color if i == best_index else accent)
