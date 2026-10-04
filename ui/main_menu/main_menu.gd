## Lists the registered drills in one tab per category and offers a language toggle.
extends Control

@onready var _margin: MarginContainer = %Center
@onready var _tabs: TabContainer = %Tabs
@onready var _language_button: Button = %LanguageButton
@onready var _progress_button: Button = %ProgressButton
@onready var _feedback_button: Button = %FeedbackButton
@onready var _training_button: Button = %TrainingButton
@onready var _theme_button: Button = %ThemeButton
@onready var _stats: HFlowContainer = %Stats
@onready var _badges: HFlowContainer = %Badges
@onready var _footer_spacer: Control = %Spacer
@onready var _quit_button: Button = %QuitButton

var _first_buttons: Array[Button] = []
var _grids: Array[GridContainer] = []


func _ready() -> void:
	for category in DrillRegistry.CATEGORY_ORDER:
		var definitions := DrillRegistry.get_by_category(category)
		if definitions.is_empty():
			continue
		_add_category_tab(category, definitions)
	_tabs.current_tab = clampi(DrillRegistry.last_menu_tab, 0, maxi(0, _tabs.get_tab_count() - 1))
	_tabs.tab_changed.connect(_on_tab_changed)
	_language_button.pressed.connect(_on_language_pressed)
	_progress_button.pressed.connect(SceneRouter.show_progress)
	_feedback_button.pressed.connect(SceneRouter.show_feedback)
	_training_button.pressed.connect(SceneRouter.show_training)
	_training_button.text = tr("MENU_TRAINING_MINUTES") % StatsStore.training_minutes
	_theme_button.pressed.connect(_on_theme_pressed)
	_theme_button.text = tr("MENU_THEME_LIGHT" if StatsStore.theme_name == "dark" else "MENU_THEME_DARK")
	_quit_button.pressed.connect(get_tree().quit)
	_quit_button.visible = not OS.has_feature("web")
	Layout.watch(self, _relayout)
	_focus_current_tab()


## One column and slim margins on a phone, two columns and wide margins otherwise.
func _relayout() -> void:
	var narrow := Layout.is_narrow(self)
	Layout.set_margins(_margin, Layout.side_margin(self), 12 if narrow else 32)
	for grid in _grids:
		grid.columns = 1 if narrow else 2
	_footer_spacer.visible = not narrow
	_build_stats(narrow)
	_build_badges(narrow)
	_tabs.clip_tabs = narrow


## One tab per category: a scrollable two-column grid with a short tab title
## and the full category name as a heading inside.
func _add_category_tab(category_key: String, definitions: Array[DrillDefinition]) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = tr(category_key + "_SHORT")
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	var heading := Label.new()
	heading.text = tr(category_key)
	heading.theme_type_variation = &"DimLabel"
	heading.add_theme_font_size_override("font_size", 22)
	column.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	column.add_child(grid)
	_grids.append(grid)
	var first: Button = null
	for definition in definitions:
		var button := _add_drill_entry(grid, definition)
		if first == null:
			first = button
	_first_buttons.append(first)


func _on_tab_changed(tab: int) -> void:
	DrillRegistry.last_menu_tab = tab
	_focus_current_tab()


func _focus_current_tab() -> void:
	var index := _tabs.current_tab
	if index >= 0 and index < _first_buttons.size() and _first_buttons[index] != null:
		_first_buttons[index].grab_focus()


func _add_drill_entry(grid: GridContainer, definition: DrillDefinition) -> Button:
	var entry := VBoxContainer.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_theme_constant_override("separation", 4)
	var button := Button.new()
	button.text = tr(definition.title_key)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.theme_type_variation = &"PrimaryButton"
	button.pressed.connect(SceneRouter.start_drill.bind(definition.id))
	entry.add_child(button)
	var description := Label.new()
	description.text = tr(definition.description_key)
	description.theme_type_variation = &"DimLabel"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(0, 0)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_child(description)
	grid.add_child(entry)
	return button


func _on_language_pressed() -> void:
	var next_locale := "en" if TranslationServer.get_locale().begins_with("cs") else "cs"
	TranslationServer.set_locale(next_locale)
	# Texts set from code do not retranslate on their own; rebuild the screen.
	SceneRouter.show_menu()


func _on_theme_pressed() -> void:
	StatsStore.set_theme_name("light" if StatsStore.theme_name == "dark" else "dark")
	_theme_button.text = tr("MENU_THEME_LIGHT" if StatsStore.theme_name == "dark" else "MENU_THEME_DARK")


## Streak, level with its XP bar and today's minutes against the daily goal.
## A phone drops the XP numbers (the bar keeps them as a tooltip).
func _build_stats(compact: bool) -> void:
	for child in _stats.get_children():
		_stats.remove_child(child)
		child.queue_free()
	var streak := StatsStore.current_streak()
	var streak_text := tr("GAMI_STREAK_NONE")
	if streak == 1:
		streak_text = tr("GAMI_STREAK_ONE")
	elif streak > 1:
		streak_text = tr("GAMI_STREAK") % streak
	_add_pill(_stats, &"StreakPill" if streak > 0 else &"Pill", streak_text, streak > 0)
	var info := StatsStore.level_info()
	var level: int = info["level"]
	var into: int = info["into"]
	var span: int = info["span"]
	var xp_pill := _add_pill(_stats, &"XpPill", tr("GAMI_LEVEL") % level, true)
	var xp_box := xp_pill.get_child(0) as BoxContainer
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"XpBar"
	bar.show_percentage = false
	bar.max_value = span
	bar.value = into
	bar.custom_minimum_size = Vector2(90, 0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.tooltip_text = tr("GAMI_XP") % [into, span]
	xp_box.add_child(bar)
	if not compact:
		var xp_label := Label.new()
		xp_label.text = tr("GAMI_XP") % [into, span]
		xp_label.theme_type_variation = &"PillLabel"
		xp_box.add_child(xp_label)
	var minutes := StatsStore.minutes_today()
	var goal := StatsStore.training_minutes
	var done := minutes >= goal
	_add_pill(_stats, &"GoalDonePill" if done else &"GoalPill", tr("GAMI_TODAY_DONE" if done else "GAMI_TODAY") % [minutes, goal], true)


## One rounded pill with a label (and room for more controls in its box).
func _add_pill(parent: Control, variation: StringName, text: String, bright: bool) -> PanelContainer:
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


## Every badge as a pill: earned ones bright, the rest dim; the description is
## the tooltip. A phone shows only the earned ones and a count, in the stats row.
func _build_badges(compact: bool) -> void:
	for child in _badges.get_children():
		_badges.remove_child(child)
		child.queue_free()
	_badges.visible = not compact
	var parent: Container = _stats if compact else _badges
	var earned := StatsStore.earned_badges()
	if compact:
		_add_pill(parent, &"Pill", tr("GAMI_BADGES") % [earned.size(), Gamification.BADGE_ORDER.size()], false)
	for id in Gamification.BADGE_ORDER:
		var has := earned.has(id)
		if compact and not has:
			continue
		var pill := PanelContainer.new()
		pill.theme_type_variation = &"BadgePill" if has else &"BadgeOffPill"
		pill.tooltip_text = tr("BADGE_%s_DESC" % id.to_upper())
		var label := Label.new()
		label.text = tr("BADGE_%s" % id.to_upper())
		label.theme_type_variation = &"BadgeLabel" if has else &"BadgeOffLabel"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(label)
		parent.add_child(pill)
