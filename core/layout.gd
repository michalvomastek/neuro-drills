## Screen-size rules shared by every screen. The window is scaled so that its
## shorter side measures a fixed number of design units: 720 in landscape (the
## 1280×720 the screens were designed at) and 480 in portrait, where a phone
## needs larger controls relative to its width. Screens then ask [method is_narrow]
## to switch to a one-column layout.
class_name Layout
extends RefCounted

const LANDSCAPE_SHORT_SIDE := 720.0
const PORTRAIT_SHORT_SIDE := 480.0
## Below this width (in design units) screens use their narrow layout.
const NARROW_WIDTH := 700.0
const NARROW_MARGIN := 12


## Design-unit size of the content area for a window of [param window_size] pixels.
static func scale_size(window_size: Vector2i) -> Vector2i:
	var portrait := window_size.y > window_size.x
	var short_side := float(mini(window_size.x, window_size.y))
	var base := PORTRAIT_SHORT_SIDE if portrait else LANDSCAPE_SHORT_SIDE
	var factor := maxf(short_side, 1.0) / base
	return Vector2i(roundi(window_size.x / factor), roundi(window_size.y / factor))


## Applies the scale to [param window]; call once and on every resize.
static func apply_scale(window: Window) -> void:
	window.content_scale_size = scale_size(window.size)


## Calls [param relayout] now and after every window resize, for as long as
## [param control] lives (the callable must be a method of the control, so the
## connection goes away with it).
static func watch(control: Control, relayout: Callable) -> void:
	relayout.call()
	var window := control.get_tree().root
	if not window.size_changed.is_connected(relayout):
		window.size_changed.connect(relayout)


static func viewport_width(control: Control) -> float:
	return control.get_viewport_rect().size.x


static func is_narrow(control: Control) -> bool:
	return viewport_width(control) < NARROW_WIDTH


## Side margin of a full-screen panel: generous on a wide screen, slim on a phone.
static func side_margin(control: Control) -> int:
	if is_narrow(control):
		return NARROW_MARGIN
	return clampi(int(viewport_width(control) * 0.09), 24, 120)


static func set_margins(margin: MarginContainer, horizontal: int, vertical: int) -> void:
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)


## Width of the content of a centred PanelContainer: the design width on a
## wide screen, the whole width minus slim margins and the panel's own
## padding on a narrow one.
static func panel_width(control: Control, design_width: float) -> float:
	var padding := control.get_theme_stylebox("panel", "PanelContainer").get_minimum_size().x
	return minf(design_width, viewport_width(control) - 2.0 * NARROW_MARGIN - padding)
