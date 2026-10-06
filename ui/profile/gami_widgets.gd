## Pills for the gamification numbers, shared by the menu and the profile.
class_name GamiWidgets
extends RefCounted


## One rounded pill with a label; returns the pill (its HBox takes more controls).
static func add_pill(parent: Control, variation: StringName, text: String, bright: bool) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.theme_type_variation = variation
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	pill.add_child(box)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"PillLabel" if bright else &"DimLabel"
	box.add_child(label)
	parent.add_child(pill)
	return pill


## Streak, level with its XP bar and today's minutes against the daily goal.
## [param compact] drops the XP numbers (the bar keeps them as a tooltip);
## [param with_daily] false leaves out the streak and the goal, which the
## app's top bar already shows above the menu.
static func add_stats(parent: Control, compact: bool, with_daily: bool = true) -> void:
	var streak := StatsStore.current_streak()
	var streak_text := TranslationServer.translate("GAMI_STREAK_NONE")
	if streak == 1:
		streak_text = TranslationServer.translate("GAMI_STREAK_ONE")
	elif streak > 1:
		streak_text = TranslationServer.translate("GAMI_STREAK") % streak
	if with_daily:
		add_pill(parent, &"StreakPill" if streak > 0 else &"Pill", streak_text, streak > 0)
	var info := StatsStore.level_info()
	var level: int = info["level"]
	var into: int = info["into"]
	var span: int = info["span"]
	var xp_pill := add_pill(parent, &"XpPill", TranslationServer.translate("GAMI_LEVEL") % level, true)
	var xp_box := xp_pill.get_child(0) as BoxContainer
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"XpBar"
	bar.show_percentage = false
	bar.max_value = span
	bar.value = into
	bar.custom_minimum_size = Vector2(90, 0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.tooltip_text = TranslationServer.translate("GAMI_XP") % [into, span]
	xp_box.add_child(bar)
	if not compact:
		var xp_label := Label.new()
		xp_label.text = TranslationServer.translate("GAMI_XP") % [into, span]
		xp_label.theme_type_variation = &"PillLabel"
		xp_box.add_child(xp_label)
	if not with_daily:
		return
	var minutes := StatsStore.minutes_today()
	var goal := Gamification.DAILY_GOAL_MINUTES
	var done := minutes >= goal
	add_pill(parent, &"GoalDonePill" if done else &"GoalPill", TranslationServer.translate("GAMI_TODAY_DONE" if done else "GAMI_TODAY") % [minutes, goal], true)


const ICON_DIR := "res://assets/icons/"
## Discs the size of the level ring, so the row reads as one set.
const STAT_ICON_SIZE := 20.0
const STAT_DISC_SIZE := XpRing.DIAMETER


## A coloured disc with an icon (white, or [param icon_color]) and a plain
## number next to it. With [param on_pressed] the chip sits inside a flat
## Button, so it activates on release, takes keyboard focus and shows it.
static func add_stat_chip(parent: Control, color: Color, icon_name: String, text: String, tooltip: String, on_pressed: Callable = Callable(), icon_color: Color = Color.WHITE) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 7)
	chip.tooltip_text = tooltip
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var disc := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(roundi(STAT_DISC_SIZE / 2.0))
	disc.add_theme_stylebox_override("panel", style)
	disc.custom_minimum_size = Vector2(STAT_DISC_SIZE, STAT_DISC_SIZE)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = load(ICON_DIR + icon_name + ".svg") as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(STAT_ICON_SIZE, STAT_ICON_SIZE)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = icon_color
	disc.add_child(icon)
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
	if streak == 1:
		streak_tip = TranslationServer.translate("GAMI_STREAK_ONE")
	elif streak > 1:
		streak_tip = TranslationServer.translate("GAMI_STREAK") % streak
	add_stat_chip(parent, parent.get_theme_color("orange" if streak > 0 else "dim", "App"), "stat_streak", str(streak), streak_tip)
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
