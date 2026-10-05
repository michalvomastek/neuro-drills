## Builds the two app themes ("soft arcs" style: rounded cards, 3D buttons,
## Baloo 2 headings, Nunito text) from one palette each and saves them as
## ui/theme/dark_theme.tres and ui/theme/light_theme.tres.
## Run through `tools/godot.sh theme`; edit the palettes here, not the .tres.
extends SceneTree

const OUT_DIR := "res://ui/theme/"
const TEXT_FONT := "res://assets/fonts/nunito.ttf"
const HEADING_FONT := "res://assets/fonts/baloo2.ttf"
## Arrows, geometric shapes, box drawing, check marks: a DejaVu Sans subset,
## because the web export has no system fonts to fall back to.
const SYMBOL_FONT := "res://assets/fonts/symbols.ttf"
const RADIUS := 16
const CARD_RADIUS := 20
const PANEL_RADIUS := 24
const PILL := 999
const LIFT := 4

const PALETTES := {
	"dark": {
		"bg": Color("171a2b"),
		"panel": Color("222638"),
		"card": Color("2f3450"),
		"card_hover": Color("3a4061"),
		"card_shadow": Color("1b1e2e"),
		"sunken": Color("1b1e2e"),
		"line": Color("353a55"),
		"text": Color("eef0fa"),
		"dim": Color("aab1cc"),
		"muted": Color("6c7390"),
		"title": Color("8ea6ff"),
		"primary": Color("6c8cff"),
		"primary_hover": Color("7c9bff"),
		"primary_shadow": Color("3f55b8"),
		"accent": Color("b48cff"),
		"green": Color("2bb673"),
		"green_bright": Color("5fe3a1"),
		"green_shadow": Color("1f8f5a"),
		"orange": Color("ff9a62"),
		"red": Color("ff6a7a"),
		"red_dim": Color("7a3340"),
		"yellow": Color("ffcf5c"),
		"tab": Color(1, 1, 1, 0.06),
		"tab_hover": Color(1, 1, 1, 0.12),
		"shadow": Color(0, 0, 0, 0.3),
		"focus": Color("9db3ff"),
		"pad": Color("20233a"),
		"cell": Color("2f3450"),
		"cell_found": Color("1b1e2e"),
		"lit": Color("7c9bff"),
		"selected": Color("4a5a9a"),
		"occluder": Color("353a55"),
		"ink": Color("eef0fa"),
		"level_none": Color("4a5070"),
		"level_beginner": Color("6c7390"),
		"level_advanced": Color("6c8cff"),
		"level_elite": Color("2bb673"),
		"badge_text": Color("3a2e05"),
	},
	"light": {
		"bg": Color("eaf0ff"),
		"panel": Color("ffffff"),
		"card": Color("f1f4fd"),
		"card_hover": Color("e6ebfa"),
		"card_shadow": Color("d6dcf0"),
		"sunken": Color("e3e8f6"),
		"line": Color("dfe4f3"),
		"text": Color("2b2d42"),
		"dim": Color("6b7280"),
		"muted": Color("b8bcc8"),
		"title": Color("4f6df5"),
		"primary": Color("4f6df5"),
		"primary_hover": Color("6680ff"),
		"primary_shadow": Color("3650c9"),
		"accent": Color("8f6bff"),
		"green": Color("2bb673"),
		"green_bright": Color("5fe3a1"),
		"green_shadow": Color("1f8f5a"),
		"orange": Color("ff7a59"),
		"red": Color("e5484d"),
		"red_dim": Color("f3b8bb"),
		"yellow": Color("e2a200"),
		"tab": Color(1, 1, 1, 0.6),
		"tab_hover": Color(1, 1, 1, 0.9),
		"shadow": Color(0.27, 0.35, 0.55, 0.14),
		"focus": Color("3650c9"),
		"pad": Color("dbe2f4"),
		"cell": Color("ffffff"),
		"cell_found": Color("eef1fb"),
		"lit": Color("4f6df5"),
		"selected": Color("b9c6ff"),
		"occluder": Color("c9d0e6"),
		"ink": Color("2b2d42"),
		"level_none": Color("b8bcc8"),
		"level_beginner": Color("8f96a8"),
		"level_advanced": Color("4f6df5"),
		"level_elite": Color("2bb673"),
		"badge_text": Color("ffffff"),
	},
}

var _text_font: FontFile
var _heading_font: FontFile
var _symbol_font: FontFile
var _fonts: Dictionary = {}


func _initialize() -> void:
	_text_font = load(TEXT_FONT) as FontFile
	_heading_font = load(HEADING_FONT) as FontFile
	_symbol_font = load(SYMBOL_FONT) as FontFile
	if _text_font == null or _heading_font == null or _symbol_font == null:
		push_error("make_theme: fonts not imported; run `tools/godot.sh import` first")
		quit(1)
		return
	for name: String in PALETTES:
		var palette: Dictionary = PALETTES[name]
		var theme := _build(palette)
		var path := OUT_DIR + name + "_theme.tres"
		var err := ResourceSaver.save(theme, path)
		if err != OK:
			push_error("make_theme: cannot save %s (%s)" % [path, error_string(err)])
			quit(1)
			return
		print("wrote %s" % path)
	quit(0)


func _c(p: Dictionary, key: String) -> Color:
	var color: Color = p[key]
	return color


func _font(base: FontFile, weight: int) -> FontVariation:
	var key := "%s:%d" % [base.resource_path, weight]
	if _fonts.has(key):
		var cached: FontVariation = _fonts[key]
		return cached
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): weight}
	variation.fallbacks = [_symbol_font]
	_fonts[key] = variation
	return variation


## Rounded box; a positive [param lift] draws a darker bottom edge so the box
## looks raised, with the content margin enlarged to keep the text clear of it.
func _box(bg: Color, radius: int, margins: Vector4 = Vector4(20, 10, 20, 10), lift: int = 0, lift_color: Color = Color.BLACK) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(radius)
	box.corner_detail = 12
	box.content_margin_left = margins.x
	box.content_margin_top = margins.y
	box.content_margin_right = margins.z
	box.content_margin_bottom = margins.w + lift
	if lift > 0:
		box.border_width_bottom = lift
		box.border_color = lift_color
	return box


## The same box pushed down: no edge, content shifted by the lift.
func _box_pressed(bg: Color, radius: int, margins: Vector4 = Vector4(20, 10, 20, 10), lift: int = LIFT) -> StyleBoxFlat:
	return _box(bg, radius, Vector4(margins.x, margins.y + lift, margins.z, margins.w))


func _outline(color: Color, radius: int, width: int = 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.set_border_width_all(width)
	box.border_color = color
	box.set_corner_radius_all(radius)
	box.corner_detail = 12
	return box


func _shadowed(box: StyleBoxFlat, color: Color, size: int, offset: Vector2) -> StyleBoxFlat:
	box.shadow_color = color
	box.shadow_size = size
	box.shadow_offset = offset
	return box


func _circle(color: Color, diameter: int) -> ImageTexture:
	var image := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var centre := Vector2(diameter, diameter) * 0.5
	var radius := diameter * 0.5
	for y in diameter:
		for x in diameter:
			var d := (Vector2(x + 0.5, y + 0.5) - centre).length()
			var alpha := clampf(radius - d + 0.5, 0.0, 1.0)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * alpha))
	return ImageTexture.create_from_image(image)


func _build(p: Dictionary) -> Theme:
	var t := Theme.new()
	var text := _font(_text_font, 600)
	var bold := _font(_text_font, 800)
	var heading := _font(_heading_font, 800)
	var empty := StyleBoxEmpty.new()
	t.default_font = text
	t.default_font_size = 20

	# App-wide colours read from code.
	t.set_color("bg", "App", _c(p, "bg"))
	t.set_color("text", "App", _c(p, "text"))
	t.set_color("dim", "App", _c(p, "dim"))
	t.set_color("primary", "App", _c(p, "primary"))
	t.set_color("accent", "App", _c(p, "accent"))
	t.set_color("green", "App", _c(p, "green"))
	t.set_color("orange", "App", _c(p, "orange"))
	t.set_color("red", "App", _c(p, "red"))
	t.set_color("yellow", "App", _c(p, "yellow"))
	t.set_color("line", "App", _c(p, "line"))
	t.set_color("sunken", "App", _c(p, "sunken"))
	t.set_color("level_none", "App", _c(p, "level_none"))
	t.set_color("level_beginner", "App", _c(p, "level_beginner"))
	t.set_color("level_advanced", "App", _c(p, "level_advanced"))
	t.set_color("level_elite", "App", _c(p, "level_elite"))

	# Labels.
	t.set_color("font_color", "Label", _c(p, "text"))
	t.set_type_variation("DimLabel", "Label")
	t.set_color("font_color", "DimLabel", _c(p, "dim"))
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", heading)
	t.set_font_size("font_size", "TitleLabel", 40)
	t.set_color("font_color", "TitleLabel", _c(p, "title"))
	t.set_type_variation("HeadingLabel", "Label")
	t.set_font("font", "HeadingLabel", heading)
	t.set_font_size("font_size", "HeadingLabel", 26)
	t.set_color("font_color", "HeadingLabel", _c(p, "text"))
	t.set_type_variation("StimulusLabel", "Label")
	t.set_font("font", "StimulusLabel", bold)
	t.set_type_variation("PillLabel", "Label")
	t.set_font("font", "PillLabel", bold)
	t.set_font_size("font_size", "PillLabel", 15)
	t.set_color("font_color", "PillLabel", Color.WHITE)
	t.set_type_variation("RichLabel", "RichTextLabel")

	# Buttons: raised cards.
	var margins := Vector4(20, 10, 20, 10)
	t.set_font("font", "Button", bold)
	t.set_stylebox("normal", "Button", _box(_c(p, "card"), RADIUS, margins, LIFT, _c(p, "card_shadow")))
	t.set_stylebox("hover", "Button", _box(_c(p, "card_hover"), RADIUS, margins, LIFT, _c(p, "card_shadow")))
	t.set_stylebox("pressed", "Button", _box_pressed(_c(p, "card_hover"), RADIUS, margins))
	t.set_stylebox("hover_pressed", "Button", _box_pressed(_c(p, "card_hover"), RADIUS, margins))
	t.set_stylebox("disabled", "Button", _box(_c(p, "sunken"), RADIUS, margins, LIFT, _c(p, "sunken")))
	t.set_stylebox("focus", "Button", _outline(_c(p, "focus"), RADIUS))
	t.set_color("font_color", "Button", _c(p, "text"))
	t.set_color("font_hover_color", "Button", _c(p, "text"))
	t.set_color("font_pressed_color", "Button", _c(p, "text"))
	t.set_color("font_hover_pressed_color", "Button", _c(p, "text"))
	t.set_color("font_focus_color", "Button", _c(p, "text"))
	t.set_color("font_disabled_color", "Button", _c(p, "muted"))
	t.set_color("icon_normal_color", "Button", _c(p, "text"))
	t.set_color("icon_hover_color", "Button", _c(p, "text"))
	t.set_color("icon_pressed_color", "Button", _c(p, "text"))
	t.set_color("icon_focus_color", "Button", _c(p, "text"))
	t.set_color("icon_hover_pressed_color", "Button", _c(p, "text"))
	t.set_color("icon_disabled_color", "Button", _c(p, "muted"))
	t.set_constant("h_separation", "Button", 8)

	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", _box(_c(p, "primary"), RADIUS, margins, LIFT, _c(p, "primary_shadow")))
	t.set_stylebox("hover", "PrimaryButton", _box(_c(p, "primary_hover"), RADIUS, margins, LIFT, _c(p, "primary_shadow")))
	t.set_stylebox("pressed", "PrimaryButton", _box_pressed(_c(p, "primary_hover"), RADIUS, margins))
	t.set_stylebox("hover_pressed", "PrimaryButton", _box_pressed(_c(p, "primary_hover"), RADIUS, margins))
	t.set_stylebox("disabled", "PrimaryButton", _box(_c(p, "sunken"), RADIUS, margins, LIFT, _c(p, "sunken")))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(state, "PrimaryButton", Color.WHITE)

	# Compact buttons for toggles inside a panel (chart range, RPE).
	var small := Vector4(12, 4, 12, 4)
	t.set_type_variation("SmallButton", "Button")
	t.set_stylebox("normal", "SmallButton", _box(_c(p, "card"), 12, small, 3, _c(p, "card_shadow")))
	t.set_stylebox("hover", "SmallButton", _box(_c(p, "card_hover"), 12, small, 3, _c(p, "card_shadow")))
	t.set_stylebox("pressed", "SmallButton", _box_pressed(_c(p, "card_hover"), 12, small, 3))
	t.set_stylebox("hover_pressed", "SmallButton", _box_pressed(_c(p, "card_hover"), 12, small, 3))
	t.set_stylebox("focus", "SmallButton", _outline(_c(p, "focus"), 12))
	t.set_font_size("font_size", "SmallButton", 16)
	t.set_type_variation("SmallPrimaryButton", "Button")
	t.set_stylebox("normal", "SmallPrimaryButton", _box(_c(p, "primary"), 12, small, 3, _c(p, "primary_shadow")))
	t.set_stylebox("hover", "SmallPrimaryButton", _box(_c(p, "primary_hover"), 12, small, 3, _c(p, "primary_shadow")))
	t.set_stylebox("pressed", "SmallPrimaryButton", _box_pressed(_c(p, "primary_hover"), 12, small, 3))
	t.set_stylebox("hover_pressed", "SmallPrimaryButton", _box_pressed(_c(p, "primary_hover"), 12, small, 3))
	t.set_stylebox("focus", "SmallPrimaryButton", _outline(_c(p, "focus"), 12))
	t.set_font_size("font_size", "SmallPrimaryButton", 16)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(state, "SmallPrimaryButton", Color.WHITE)

	# Tile-like buttons inside a drill (the title card of a drill entry).
	t.set_type_variation("CardButton", "Button")
	var card_margins := Vector4(18, 14, 18, 14)
	t.set_stylebox("normal", "CardButton", _box(_c(p, "card"), CARD_RADIUS, card_margins, LIFT, _c(p, "card_shadow")))
	t.set_stylebox("hover", "CardButton", _box(_c(p, "card_hover"), CARD_RADIUS, card_margins, LIFT, _c(p, "card_shadow")))
	t.set_stylebox("pressed", "CardButton", _box_pressed(_c(p, "card_hover"), CARD_RADIUS, card_margins))
	t.set_stylebox("hover_pressed", "CardButton", _box_pressed(_c(p, "card_hover"), CARD_RADIUS, card_margins))
	t.set_stylebox("focus", "CardButton", _outline(_c(p, "focus"), CARD_RADIUS))
	t.set_font("font", "CardButton", heading)
	t.set_font_size("font_size", "CardButton", 24)

	# Pads: flat response targets; colours are read from code.
	t.set_type_variation("Pad", "Button")
	var pad := _box(_c(p, "pad"), CARD_RADIUS, Vector4(16, 12, 16, 12))
	t.set_stylebox("normal", "Pad", pad)
	t.set_stylebox("hover", "Pad", pad)
	t.set_stylebox("pressed", "Pad", pad)
	t.set_stylebox("hover_pressed", "Pad", pad)
	t.set_stylebox("disabled", "Pad", pad)
	t.set_stylebox("focus", "Pad", empty)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(state, "Pad", _c(p, "text"))
	t.set_color("go", "Pad", _c(p, "green"))
	t.set_color("correct", "Pad", _c(p, "green"))
	t.set_color("wrong", "Pad", _c(p, "red"))
	t.set_color("wrong_dim", "Pad", _c(p, "red_dim"))

	# Schulte cells: raised tiles that sink when found.
	t.set_type_variation("SchulteCell", "Button")
	var cell_margins := Vector4(4, 4, 4, 4)
	var cell := _box(_c(p, "cell"), 14, cell_margins, LIFT, _c(p, "card_shadow"))
	t.set_stylebox("normal", "SchulteCell", cell)
	t.set_stylebox("hover", "SchulteCell", _box(_c(p, "card_hover"), 14, cell_margins, LIFT, _c(p, "card_shadow")))
	t.set_stylebox("pressed", "SchulteCell", _box_pressed(_c(p, "card_hover"), 14, cell_margins))
	t.set_stylebox("hover_pressed", "SchulteCell", _box_pressed(_c(p, "card_hover"), 14, cell_margins))
	t.set_stylebox("disabled", "SchulteCell", _box_pressed(_c(p, "cell_found"), 14, cell_margins))
	t.set_stylebox("focus", "SchulteCell", empty)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(state, "SchulteCell", _c(p, "text"))
	t.set_color("font_disabled_color", "SchulteCell", _c(p, "muted"))
	t.set_font("font", "SchulteCell", heading)
	t.set_color("correct_flash", "SchulteCell", _c(p, "green"))
	t.set_color("wrong_flash", "SchulteCell", _c(p, "red"))
	t.set_color("red", "SchulteCell", _c(p, "red"))

	# Panels and cards.
	var panel := _shadowed(_box(_c(p, "panel"), PANEL_RADIUS, Vector4(32, 28, 32, 28)), _c(p, "shadow"), 16, Vector2(0, 8))
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", _box(_c(p, "card"), CARD_RADIUS, Vector4(18, 14, 18, 14)))
	t.set_type_variation("Sunken", "PanelContainer")
	t.set_stylebox("panel", "Sunken", _box(_c(p, "sunken"), RADIUS, Vector4(16, 12, 16, 12)))
	t.set_type_variation("Pill", "PanelContainer")
	t.set_stylebox("panel", "Pill", _box(_c(p, "sunken"), PILL, Vector4(14, 6, 14, 6)))
	var pill_margins := Vector4(14, 6, 14, 6)
	t.set_type_variation("StreakPill", "PanelContainer")
	t.set_stylebox("panel", "StreakPill", _box(_c(p, "orange"), PILL, pill_margins))
	t.set_type_variation("XpPill", "PanelContainer")
	t.set_stylebox("panel", "XpPill", _box(_c(p, "accent"), PILL, pill_margins))
	t.set_type_variation("GoalPill", "PanelContainer")
	t.set_stylebox("panel", "GoalPill", _box(_c(p, "primary"), PILL, pill_margins))
	t.set_type_variation("GoalDonePill", "PanelContainer")
	t.set_stylebox("panel", "GoalDonePill", _box(_c(p, "green"), PILL, pill_margins))
	t.set_type_variation("BadgePill", "PanelContainer")
	t.set_stylebox("panel", "BadgePill", _box(_c(p, "yellow"), PILL, Vector4(12, 4, 12, 4)))
	t.set_type_variation("BadgeOffPill", "PanelContainer")
	t.set_stylebox("panel", "BadgeOffPill", _box(_c(p, "sunken"), PILL, Vector4(12, 4, 12, 4)))
	t.set_type_variation("BadgeLabel", "Label")
	t.set_font("font", "BadgeLabel", bold)
	t.set_font_size("font_size", "BadgeLabel", 15)
	t.set_color("font_color", "BadgeLabel", _c(p, "badge_text"))
	t.set_type_variation("BadgeOffLabel", "Label")
	t.set_font("font", "BadgeOffLabel", bold)
	t.set_font_size("font_size", "BadgeOffLabel", 15)
	t.set_color("font_color", "BadgeOffLabel", _c(p, "muted"))
	t.set_type_variation("XpBar", "ProgressBar")
	t.set_stylebox("background", "XpBar", _box(_c(p, "sunken"), PILL, Vector4(0, 5, 0, 5)))
	t.set_stylebox("fill", "XpBar", _box(_c(p, "accent"), PILL, Vector4(0, 5, 0, 5)))
	t.set_type_variation("PlainPanel", "PanelContainer")
	t.set_stylebox("panel", "PlainPanel", empty)
	t.set_type_variation("Board", "Panel")
	t.set_stylebox("panel", "Board", _box(_c(p, "pad"), CARD_RADIUS, Vector4(0, 0, 0, 0)))
	t.set_color("cell", "Board", _c(p, "cell"))
	t.set_color("lit", "Board", _c(p, "lit"))
	t.set_color("occluder", "Board", _c(p, "occluder"))
	t.set_color("selected", "Board", _c(p, "selected"))
	t.set_color("task_magnitude", "Board", _c(p, "orange"))
	t.set_color("task_parity", "Board", _c(p, "lit"))
	t.set_color("ink", "Board", _c(p, "ink"))
	t.set_color("line", "Board", _c(p, "line"))

	# Tabs as pills, content without a frame.
	var tab_margins := Vector4(18, 8, 18, 8)
	t.set_stylebox("tab_selected", "TabContainer", _box(_c(p, "primary"), PILL, tab_margins))
	t.set_stylebox("tab_unselected", "TabContainer", _box(_c(p, "tab"), PILL, tab_margins))
	t.set_stylebox("tab_hovered", "TabContainer", _box(_c(p, "tab_hover"), PILL, tab_margins))
	t.set_stylebox("tab_disabled", "TabContainer", _box(_c(p, "tab"), PILL, tab_margins))
	t.set_stylebox("tab_focus", "TabContainer", _outline(_c(p, "focus"), PILL))
	var tab_panel := StyleBoxEmpty.new()
	tab_panel.content_margin_top = 14
	t.set_stylebox("panel", "TabContainer", tab_panel)
	t.set_stylebox("tabbar_background", "TabContainer", empty)
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", _c(p, "dim"))
	t.set_color("font_hovered_color", "TabContainer", _c(p, "text"))
	t.set_color("font_disabled_color", "TabContainer", _c(p, "muted"))
	t.set_font("font", "TabContainer", bold)
	t.set_font_size("font_size", "TabContainer", 18)
	t.set_constant("side_margin", "TabContainer", 0)
	t.set_constant("tab_separation", "TabContainer", 6)
	t.set_color("font_selected_color", "TabBar", Color.WHITE)
	t.set_color("font_unselected_color", "TabBar", _c(p, "dim"))
	t.set_color("font_hovered_color", "TabBar", _c(p, "text"))
	t.set_stylebox("tab_selected", "TabBar", _box(_c(p, "primary"), PILL, tab_margins))
	t.set_stylebox("tab_unselected", "TabBar", _box(_c(p, "tab"), PILL, tab_margins))
	t.set_stylebox("tab_hovered", "TabBar", _box(_c(p, "tab_hover"), PILL, tab_margins))
	t.set_stylebox("tab_focus", "TabBar", _outline(_c(p, "focus"), PILL))
	t.set_font("font", "TabBar", bold)
	t.set_font_size("font_size", "TabBar", 18)
	t.set_constant("tab_separation", "TabBar", 6)

	# Toggles.
	for type: String in ["CheckBox", "CheckButton"]:
		t.set_font("font", type, text)
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			t.set_color(state, type, _c(p, "text"))
		t.set_color("font_disabled_color", type, _c(p, "muted"))
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(state, type, _box(Color.TRANSPARENT, RADIUS, Vector4(4, 6, 4, 6)))
		t.set_stylebox("focus", type, _outline(_c(p, "focus"), RADIUS))
	t.set_color("checkbox_checked_color", "CheckBox", _c(p, "primary"))
	t.set_color("checkbox_unchecked_color", "CheckBox", _c(p, "dim"))
	t.set_color("button_checked_color", "CheckButton", _c(p, "primary"))
	t.set_color("button_unchecked_color", "CheckButton", _c(p, "dim"))

	# Sliders and progress bars.
	var track := _box(_c(p, "sunken"), PILL, Vector4(0, 4, 0, 4))
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", _box(_c(p, "primary"), PILL, Vector4(0, 4, 0, 4)))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(_c(p, "primary_hover"), PILL, Vector4(0, 4, 0, 4)))
	t.set_icon("grabber", "HSlider", _circle(_c(p, "primary"), 24))
	t.set_icon("grabber_highlight", "HSlider", _circle(_c(p, "primary_hover"), 24))
	t.set_icon("grabber_disabled", "HSlider", _circle(_c(p, "muted"), 24))
	t.set_constant("grabber_offset", "HSlider", 0)
	t.set_stylebox("background", "ProgressBar", _box(_c(p, "sunken"), PILL, Vector4(0, 6, 0, 6)))
	t.set_stylebox("fill", "ProgressBar", _box(_c(p, "primary"), PILL, Vector4(0, 6, 0, 6)))
	t.set_color("font_color", "ProgressBar", _c(p, "text"))
	t.set_font_size("font_size", "ProgressBar", 14)

	# Text input, option menus, tooltips, dialogs.
	t.set_stylebox("normal", "LineEdit", _box(_c(p, "sunken"), 12, Vector4(12, 8, 12, 8)))
	t.set_stylebox("read_only", "LineEdit", _box(_c(p, "sunken"), 12, Vector4(12, 8, 12, 8)))
	t.set_stylebox("focus", "LineEdit", _outline(_c(p, "primary"), 12))
	t.set_color("font_color", "LineEdit", _c(p, "text"))
	t.set_color("font_placeholder_color", "LineEdit", _c(p, "muted"))
	t.set_color("font_uneditable_color", "LineEdit", _c(p, "dim"))
	t.set_color("caret_color", "LineEdit", _c(p, "primary"))
	var selection := _c(p, "primary")
	selection.a = 0.35
	t.set_color("selection_color", "LineEdit", selection)
	t.set_stylebox("normal", "TextEdit", _box(_c(p, "sunken"), 12, Vector4(12, 8, 12, 8)))
	t.set_stylebox("focus", "TextEdit", _outline(_c(p, "primary"), 12))
	t.set_color("font_color", "TextEdit", _c(p, "text"))
	t.set_color("font_placeholder_color", "TextEdit", _c(p, "muted"))
	t.set_color("caret_color", "TextEdit", _c(p, "primary"))
	t.set_color("selection_color", "TextEdit", selection)
	t.set_constant("modulate_arrow", "OptionButton", 1)
	var popup_panel := _shadowed(_box(_c(p, "card"), 16, Vector4(8, 8, 8, 8)), _c(p, "shadow"), 12, Vector2(0, 6))
	popup_panel.set_border_width_all(1)
	popup_panel.border_color = _c(p, "line")
	t.set_stylebox("panel", "PopupPanel", popup_panel)
	t.set_stylebox("panel", "PopupMenu", _shadowed(_box(_c(p, "card"), 14, Vector4(6, 6, 6, 6)), _c(p, "shadow"), 12, Vector2(0, 6)))
	t.set_stylebox("hover", "PopupMenu", _box(_c(p, "primary"), 10, Vector4(10, 4, 10, 4)))
	t.set_color("font_color", "PopupMenu", _c(p, "text"))
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", _c(p, "muted"))
	t.set_color("font_separator_color", "PopupMenu", _c(p, "dim"))
	t.set_font("font", "PopupMenu", text)
	t.set_constant("v_separation", "PopupMenu", 6)
	t.set_constant("item_start_padding", "PopupMenu", 10)
	t.set_constant("item_end_padding", "PopupMenu", 10)
	t.set_stylebox("panel", "TooltipPanel", _box(_c(p, "card"), 10, Vector4(10, 6, 10, 6)))
	t.set_color("font_color", "TooltipLabel", _c(p, "text"))
	t.set_stylebox("panel", "AcceptDialog", _box(_c(p, "panel"), 0, Vector4(16, 16, 16, 16)))
	t.set_stylebox("embedded_border", "Window", _box(_c(p, "panel"), 0, Vector4(0, 0, 0, 0)))
	t.set_stylebox("embedded_unfocused_border", "Window", _box(_c(p, "panel"), 0, Vector4(0, 0, 0, 0)))
	t.set_color("title_color", "Window", _c(p, "text"))
	t.set_font("title_font", "Window", heading)
	t.set_font_size("title_font_size", "Window", 22)

	# Separators and scrollbars.
	var separator := StyleBoxLine.new()
	separator.color = _c(p, "line")
	separator.thickness = 2
	separator.grow_begin = 0
	separator.grow_end = 0
	t.set_stylebox("separator", "HSeparator", separator)
	var vseparator := StyleBoxLine.new()
	vseparator.color = _c(p, "line")
	vseparator.thickness = 2
	vseparator.vertical = true
	t.set_stylebox("separator", "VSeparator", vseparator)
	t.set_stylebox("panel", "ScrollContainer", empty)
	t.set_stylebox("focus", "ScrollContainer", empty)
	var grabber_color := _c(p, "dim")
	grabber_color.a = 0.45
	for bar: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, _box(Color.TRANSPARENT, PILL, Vector4(3, 3, 3, 3)))
		t.set_stylebox("scroll_focus", bar, _box(Color.TRANSPARENT, PILL, Vector4(3, 3, 3, 3)))
		t.set_stylebox("grabber", bar, _box(grabber_color, PILL, Vector4(3, 3, 3, 3)))
		t.set_stylebox("grabber_highlight", bar, _box(_c(p, "dim"), PILL, Vector4(3, 3, 3, 3)))
		t.set_stylebox("grabber_pressed", bar, _box(_c(p, "dim"), PILL, Vector4(3, 3, 3, 3)))

	# Rich text.
	t.set_color("default_color", "RichTextLabel", _c(p, "text"))
	t.set_font("normal_font", "RichTextLabel", text)
	t.set_font("bold_font", "RichTextLabel", bold)
	t.set_stylebox("normal", "RichTextLabel", empty)
	return t
