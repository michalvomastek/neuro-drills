## Lists the registered drills in one tab per category and offers a language toggle.
extends Control

@onready var _margin: MarginContainer = %Center
@onready var _tabs: TabContainer = %Tabs
@onready var _progress_button: Button = %ProgressButton
@onready var _feedback_button: Button = %FeedbackButton
@onready var _training_button: Button = %TrainingButton
@onready var _settings_button: Button = %SettingsButton
@onready var _stats: HFlowContainer = %Stats
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
	_progress_button.pressed.connect(SceneRouter.show_progress)
	_feedback_button.pressed.connect(SceneRouter.show_feedback)
	_training_button.pressed.connect(SceneRouter.show_training)
	_training_button.text = tr("MENU_TRAINING_MINUTES") % StatsStore.training_minutes
	_settings_button.pressed.connect(SceneRouter.show_settings)
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






## Streak, level, today's goal and a pill button to the profile with the
## badge count; the phone drops the XP numbers.
func _build_stats(compact: bool) -> void:
	for child in _stats.get_children():
		_stats.remove_child(child)
		child.queue_free()
	GamiWidgets.add_stats(_stats, compact)
	var earned := StatsStore.earned_badges().size()
	GamiWidgets.add_pill_button(_stats, tr("MENU_PROFILE_BADGES") % [earned, Gamification.BADGE_ORDER.size()], SceneRouter.show_profile)
