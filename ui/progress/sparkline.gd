## Line chart of the last runs of one variant. Better is always up: when
## lower is better the value axis is flipped. The best run is marked. The
## left edge labels the top and bottom values, the bottom edge the dates of
## the first and the last shown run.
class_name Sparkline
extends Control

var values: PackedFloat64Array = PackedFloat64Array():
	set(v):
		values = v
		queue_redraw()
## Unix times of the shown runs, parallel to [member values].
var dates: PackedInt64Array = PackedInt64Array():
	set(v):
		dates = v
		queue_redraw()
var lower_is_better: bool = true:
	set(v):
		lower_is_better = v
		queue_redraw()
## Benchmark bounds drawn as dashed lines: {"advanced": x, "elite": y}; a bound
## far outside the data range is left out so it cannot flatten the line.
var bands: Dictionary = {}:
	set(v):
		bands = v
		queue_redraw()
## Unit key understood by MetricCatalog.format_value ("ms", "s", "%", ...).
var unit: String = "":
	set(v):
		unit = v
		queue_redraw()

const PADDING := 10.0
const LABEL_GAP := 8.0
const POINT_RADIUS := 4.0
const FONT_SIZE := 14


func _draw() -> void:
	var dim := get_theme_color("font_color", "DimLabel")
	var accent := get_theme_color("lit", "Board")
	var best_color := get_theme_color("correct", "Pad")
	var font := get_theme_default_font()
	var line_height := font.get_height(FONT_SIZE)
	if values.is_empty():
		return
	var low := values[0]
	var high := values[0]
	for v in values:
		low = minf(low, v)
		high = maxf(high, v)
	var shown_bands: Dictionary = {}
	var data_span := maxf(maxf(high - low, absf(high) * 0.1), 0.000001)
	for key: String in bands:
		var bound: float = bands[key]
		if bound >= low - data_span and bound <= high + data_span:
			shown_bands[key] = bound
			low = minf(low, bound)
			high = maxf(high, bound)
	var top_text := MetricCatalog.format_value(low if lower_is_better else high, unit)
	var bottom_text := MetricCatalog.format_value(high if lower_is_better else low, unit)
	var label_width := maxf(font.get_string_size(top_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x, font.get_string_size(bottom_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	var has_dates := dates.size() == values.size() and not dates.is_empty()
	var rect := Rect2(
		Vector2(PADDING + label_width + LABEL_GAP, PADDING + line_height * 0.5),
		size - Vector2(PADDING * 2.0 + label_width + LABEL_GAP, PADDING * 2.0 + line_height * 0.5 + (line_height + LABEL_GAP if has_dates else 0.0)))
	var grid_color := dim * Color(1, 1, 1, 0.35)
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), grid_color, 1.0)
	draw_line(rect.position + Vector2(0, rect.size.y), rect.end, grid_color, 1.0)
	var ascent := font.get_ascent(FONT_SIZE)
	draw_string(font, Vector2(PADDING, rect.position.y + ascent - line_height * 0.5), top_text, HORIZONTAL_ALIGNMENT_RIGHT, label_width, FONT_SIZE, dim)
	draw_string(font, Vector2(PADDING, rect.end.y + ascent - line_height * 0.5), bottom_text, HORIZONTAL_ALIGNMENT_RIGHT, label_width, FONT_SIZE, dim)
	if has_dates:
		var y := rect.end.y + LABEL_GAP + ascent
		draw_string(font, Vector2(rect.position.x, y), _date_text(dates[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, dim)
		if dates.size() > 1:
			var last := _date_text(dates[dates.size() - 1])
			var width := font.get_string_size(last, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			draw_string(font, Vector2(rect.end.x - width, y), last, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, dim)
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
	for key: String in shown_bands:
		var bound: float = shown_bands[key]
		var tb := (bound - low) / span
		if lower_is_better:
			tb = 1.0 - tb
		var by := rect.position.y + rect.size.y * (1.0 - tb)
		var band_color := get_theme_color("level_elite" if key == "elite" else "level_advanced", "App")
		draw_dashed_line(Vector2(rect.position.x, by), Vector2(rect.end.x, by), band_color, 1.5, 6.0)
		var text := tr("LEVEL_ELITE" if key == "elite" else "LEVEL_ADVANCED")
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		draw_string(font, Vector2(rect.end.x - text_width, by - 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, band_color)
	if points.size() > 1:
		draw_polyline(points, accent, 2.0, true)
	for i in points.size():
		draw_circle(points[i], POINT_RADIUS, best_color if i == best_index else accent)


## Day and month, with the year when it is not the current one.
static func _date_text(unix: int) -> String:
	var d := Time.get_date_dict_from_unix_time(unix)
	var now := Time.get_date_dict_from_system()
	var day: int = d["day"]
	var month: int = d["month"]
	var year: int = d["year"]
	var current_year: int = now["year"]
	if TranslationServer.get_locale().begins_with("cs"):
		return "%d. %d." % [day, month] if year == current_year else "%d. %d. %d" % [day, month, year]
	return "%d/%d" % [day, month] if year == current_year else "%d/%d/%d" % [day, month, year]
