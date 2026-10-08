## The gamification numbers as the top bar's ring and discs (brief chips in
## the bar, written-out rows in the profile) and the badge medallions.
class_name GamiWidgets
extends RefCounted


const ICON_DIR := "res://assets/icons/"

## Discs the size of the level ring, so the row reads as one set.
const STAT_ICON_SIZE := 20.0
const STAT_DISC_SIZE := XpRing.DIAMETER


## "%d den / dny / dní" with the Czech plural forms (English keeps day / days).
static func days_text(days: int) -> String:
	var key := "GAMI_DAYS_MANY"
	if days == 1:
		key = "GAMI_DAYS_ONE"
	elif days >= 2 and days <= 4:
		key = "GAMI_DAYS_FEW"
	return TranslationServer.translate(key) % days


## A disc like the top bar's, not yet in the tree; the caller places it.
static func make_stat_disc(color: Color, icon_name: String, icon_color: Color = Color.WHITE, size: float = STAT_DISC_SIZE, icon_size: float = STAT_ICON_SIZE) -> PanelContainer:
	var disc := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(roundi(size / 2.0))
	disc.add_theme_stylebox_override("panel", style)
	disc.custom_minimum_size = Vector2(size, size)
	disc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = load(ICON_DIR + icon_name + ".svg") as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = icon_color
	disc.add_child(icon)
	return disc


## Share of the font size above which capitals start, for Baloo 2 and
## Nunito; the label box itself begins higher (ascent plus line spacing).
const CAP_HEIGHT_RATIO := 0.72


## Places [param symbol] on the row so that its top meets the top of the
## capitals of [param title_label], not the top of the label box, which
## has empty line spacing above the glyphs. Returns the wrapper to add.
static func align_to_caps(symbol: Control, title_label: Label) -> MarginContainer:
	var font := title_label.get_theme_font("font")
	var font_size := title_label.get_theme_font_size("font_size")
	var pad := maxi(0, roundi(font.get_ascent(font_size) - font_size * CAP_HEIGHT_RATIO))
	var holder := MarginContainer.new()
	holder.add_theme_constant_override("margin_top", pad)
	holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	symbol.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	holder.add_child(symbol)
	return holder


## One profile row: the symbol from the top bar on the left, a title and a
## longer explanation on the right.
static func add_stat_row(parent: Control, symbol: Control, title: String, detail: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)
	var title_label := Label.new()
	title_label.text = title
	title_label.theme_type_variation = &"ItemLabel"
	column.add_child(title_label)
	row.add_child(align_to_caps(symbol, title_label))
	row.move_child(column, 1)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.theme_type_variation = &"NoteLabel"
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail_label)


## The four numbers of the top bar written out for the profile: level with
## the XP to go, streak, daily goal and badges.
static func add_profile_stats(parent: Control) -> void:
	var info := StatsStore.level_info()
	var level: int = info["level"]
	var into: int = info["into"]
	var span: int = info["span"]
	var ring := XpRing.new()
	ring.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_stat_row(parent, ring, TranslationServer.translate("GAMI_LEVEL") % level, TranslationServer.translate("PROFILE_LEVEL_DETAIL") % [into, span, span - into])
	ring.set_level(level, into, span)
	var streak := StatsStore.current_streak()
	var streak_title: String = TranslationServer.translate("GAMI_STREAK_NONE")
	if streak > 0:
		streak_title = "%s: %s" % [TranslationServer.translate("PROFILE_STREAK_TITLE"), days_text(streak)]
	add_stat_row(parent, make_stat_disc(parent.get_theme_color("orange" if streak > 0 else "dim", "App"), "stat_streak"), streak_title, TranslationServer.translate("PROFILE_STREAK_DETAIL"))
	var minutes := StatsStore.minutes_today()
	var goal := Gamification.DAILY_GOAL_MINUTES
	var done := minutes >= goal
	var goal_detail: String = TranslationServer.translate("PROFILE_GOAL_DETAIL") % [minutes, goal]
	if done:
		goal_detail = TranslationServer.translate("PROFILE_GOAL_DONE_DETAIL") % minutes
	add_stat_row(parent, make_stat_disc(parent.get_theme_color("green" if done else "primary", "App"), "stat_today"), TranslationServer.translate("PROFILE_GOAL_TITLE"), goal_detail)
	var earned := StatsStore.earned_badges().size()
	var total := Gamification.BADGE_ORDER.size()
	add_stat_row(parent, make_stat_disc(parent.get_theme_color("yellow", "App"), "stat_badges", parent.get_theme_color("on_yellow", "App")), TranslationServer.translate("PROFILE_BADGES_TITLE"), TranslationServer.translate("PROFILE_BADGES_DETAIL") % [earned, total])


## A coloured disc with an icon (white, or [param icon_color]) and a plain
## number next to it. With [param on_pressed] the chip sits inside a flat
## Button, so it activates on release, takes keyboard focus and shows it.
static func add_stat_chip(parent: Control, color: Color, icon_name: String, text: String, tooltip: String, on_pressed: Callable = Callable(), icon_color: Color = Color.WHITE) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 7)
	chip.tooltip_text = tooltip
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var disc := make_stat_disc(color, icon_name, icon_color)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(disc)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"PillLabel"
	label.add_theme_color_override("font_color", parent.get_theme_color("text", "App"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	if on_pressed.is_valid():
		var button := Button.new()
		button.flat = true
		button.tooltip_text = tooltip
		button.pressed.connect(on_pressed)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.set_anchors_preset(Control.PRESET_FULL_RECT)
		button.add_child(chip)
		button.custom_minimum_size = chip.get_combined_minimum_size()
		parent.add_child(button)
	else:
		parent.add_child(chip)
	return chip


## Level, streak, today's minutes and badges for the top bar: the level
## inside an XP ring, then a flame disc with the days, a clock disc with
## minutes / goal (green once the goal is reached) and a rosette disc with
## earned / all badges that opens the profile.
static func add_brief_stats(parent: Control, on_badges: Callable = Callable()) -> void:
	var info := StatsStore.level_info()
	var level: int = info["level"]
	var into: int = info["into"]
	var span: int = info["span"]
	var ring := XpRing.new()
	ring.tooltip_text = "%s · %s" % [TranslationServer.translate("GAMI_LEVEL") % level, TranslationServer.translate("GAMI_XP") % [into, span]]
	ring.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(ring)
	ring.set_level(level, into, span)
	var streak := StatsStore.current_streak()
	var streak_tip := TranslationServer.translate("GAMI_STREAK_NONE")
	if streak > 0:
		streak_tip = "%s: %s" % [TranslationServer.translate("PROFILE_STREAK_TITLE"), days_text(streak)]
	add_stat_chip(parent, parent.get_theme_color("orange" if streak > 0 else "dim", "App"), "stat_streak", days_text(streak), streak_tip)
	var minutes := StatsStore.minutes_today()
	var goal := Gamification.DAILY_GOAL_MINUTES
	var done := minutes >= goal
	add_stat_chip(parent, parent.get_theme_color("green" if done else "primary", "App"), "stat_today", TranslationServer.translate("GAMI_TODAY_SHORT") % [minutes, goal], TranslationServer.translate("GAMI_TODAY_DONE" if done else "GAMI_TODAY") % [minutes, goal])
	var earned := StatsStore.earned_badges().size()
	var total := Gamification.BADGE_ORDER.size()
	# White is lost on the bright yellow of the dark theme; the badge text colour is dark there.
	add_stat_chip(parent, parent.get_theme_color("yellow", "App"), "stat_badges", "%d/%d" % [earned, total], TranslationServer.translate("GAMI_BADGES") % [earned, total], on_badges, parent.get_theme_color("on_yellow", "App"))


const BADGE_DIR := "res://assets/badges/"
## Icons of badges not yet earned are shown faded.
const LOCKED_ALPHA := 0.3


## The coloured medallion of a badge (assets/badges/<id>.svg), [param size]
## design units across; a locked badge fades to a silhouette.
static func make_badge_icon(id: String, size: float, earned: bool) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(BADGE_DIR + id + ".svg") as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(size, size)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if not earned:
		icon.modulate = Color(1, 1, 1, LOCKED_ALPHA)
	return icon


## A small pill-shaped button, e.g. "Badges 3 / 12".
static func add_pill_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"SmallButton"
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
