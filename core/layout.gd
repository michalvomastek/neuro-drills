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


## Global zoom chosen in the settings (0.9 small, 1.0 normal, 1.15 large):
## fewer design units across the window make everything larger.
static var text_scale: float = 1.0

## Design-unit size of the content area for a window of [param window_size] pixels.
static func scale_size(window_size: Vector2i) -> Vector2i:
	var portrait := window_size.y > window_size.x
	var short_side := float(mini(window_size.x, window_size.y))
	var base := (PORTRAIT_SHORT_SIDE if portrait else LANDSCAPE_SHORT_SIDE) / text_scale
	var factor := maxf(short_side, 1.0) / base
	return Vector2i(roundi(window_size.x / factor), roundi(window_size.y / factor))


## Applies the scale to [param window]; call once and on every resize.
static func apply_scale(window: Window) -> void:
	window.content_scale_size = scale_size(window.size)


## Top and bottom insets in design units that the device reserves (the
## iPhone notch and home indicator in a web app on the home screen). The web
## head include exposes them through window.neuroSafeArea; elsewhere zero.
static func safe_insets(window: Window) -> Vector2:
	# NEURO_SAFE_INSETS="top,bottom" (design units) fakes them for headless renders.
	var forced := OS.get_environment("NEURO_SAFE_INSETS").split(",")
	if forced.size() == 2:
		return Vector2(maxf(0.0, float(forced[0])), maxf(0.0, float(forced[1])))
	if not OS.has_feature("web"):
		return Vector2.ZERO
	var raw: Variant = JavaScriptBridge.eval("(function(){try{var a=window.neuroSafeArea?window.neuroSafeArea():null;if(!a){return '0,0';}var d=window.devicePixelRatio||1;return (a.top*d)+','+(a.bottom*d);}catch(e){return '0,0';}})()", true)
	var parts := str(raw).split(",")
	if parts.size() != 2:
		return Vector2.ZERO
	var units_per_px := float(window.content_scale_size.y) / maxf(float(window.size.y), 1.0)
	return Vector2(maxf(0.0, float(parts[0])), maxf(0.0, float(parts[1]))) * units_per_px


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


## Vertical margin of a top-level screen: room under the top bar on a phone.
const SCREEN_MARGIN_NARROW := 24
const SCREEN_MARGIN_WIDE := 32


## Outer margins of a top-level screen, the same on every screen: the side
## margin of a full-screen panel and SCREEN_MARGIN_* above and below.
static func set_screen_margins(margin: MarginContainer) -> void:
	set_margins(margin, side_margin(margin), SCREEN_MARGIN_NARROW if is_narrow(margin) else SCREEN_MARGIN_WIDE)


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
