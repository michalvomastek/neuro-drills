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
	var goal := StatsStore.training_minutes
	var done := minutes >= goal
	add_pill(parent, &"GoalDonePill" if done else &"GoalPill", TranslationServer.translate("GAMI_TODAY_DONE" if done else "GAMI_TODAY") % [minutes, goal], true)


## Streak and today's minutes only, for the top bar; [param short] uses the
## compact wording that fits next to the title on a phone.
static func add_brief_stats(parent: Control, short: bool) -> void:
	var streak := StatsStore.current_streak()
	var streak_text: String
	if short:
		streak_text = TranslationServer.translate("GAMI_STREAK_SHORT") % streak
	elif streak == 1:
		streak_text = TranslationServer.translate("GAMI_STREAK_ONE")
	elif streak > 1:
		streak_text = TranslationServer.translate("GAMI_STREAK") % streak
	else:
		streak_text = TranslationServer.translate("GAMI_STREAK_NONE")
	add_pill(parent, &"StreakPill" if streak > 0 else &"Pill", streak_text, streak > 0)
	var minutes := StatsStore.minutes_today()
	var goal := StatsStore.training_minutes
	var done := minutes >= goal
	var key := "GAMI_TODAY_SHORT" if short else ("GAMI_TODAY_DONE" if done else "GAMI_TODAY")
	add_pill(parent, &"GoalDonePill" if done else &"GoalPill", TranslationServer.translate(key) % [minutes, goal], true)


## A small pill-shaped button, e.g. "Badges 3 / 12".
static func add_pill_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"SmallButton"
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
