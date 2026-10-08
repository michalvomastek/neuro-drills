## Main scene: a fixed top bar (level, streak, goal and badges, quit on the
## desktop, the screen title), the host of the current screen and a fixed
## bottom bar with the five main destinations. The bars show on the top-level
## screens and around a drill's setup panel (its title, the back arrow leaves
## the drill); a running drill, the results, a training brief or the
## onboarding take the whole window.
extends Control

const DEFAULT_LOCALE := "cs"
const ICON_DIR := "res://assets/icons/"
## One gap, in design units, between the top bar's edges, its two rows and
## the title's glyphs: the stat discs stand this far below the bar's top
## (after the safe-area inset) and above the title's capitals, and the
## title's baseline this far above the bar's bottom edge.
const TOP_BAR_GAP := 22.0

## Bottom bar tabs in order: screen id (as SceneRouter names it), label key, icon.
const NAV_ITEMS: Array[Dictionary] = [
	{"screen": &"menu", "text": "NAV_DRILLS", "icon": "nav_drills"},
	{"screen": &"training", "text": "MENU_TRAINING", "icon": "nav_training"},
	{"screen": &"progress", "text": "MENU_PROGRESS", "icon": "nav_progress"},
	{"screen": &"profile", "text": "PROFILE_TITLE", "icon": "nav_profile"},
	{"screen": &"settings", "text": "MENU_SETTINGS", "icon": "nav_settings"},
]
## Top bar title per screen; the menu shows the app name.
const TITLES: Dictionary = {
	&"menu": "APP_TITLE",
	&"training": "TRAINING_TITLE",
	&"progress": "PROGRESS_TITLE",
	&"profile": "PROFILE_TITLE",
	&"settings": "SETTINGS_TITLE",
	&"feedback": "FEEDBACK_TITLE",
}

@onready var _top_bar: PanelContainer = %TopBar
@onready var _top_rows: VBoxContainer = %TopRows
@onready var _bottom_bar: PanelContainer = %BottomBar
@onready var _host: Control = %Host
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _top_stats: HBoxContainer = %TopStats
@onready var _quit_button: Button = %QuitButton
@onready var _nav_buttons: HBoxContainer = %NavButtons

var _screen: StringName = &""
var _tabs: Dictionary = {}
## Top and bottom safe-area insets of the device in design units.
var _insets: Vector2 = Vector2.ZERO
## While iOS shows a share or file sheet the page reports no safe area, and
## the resize that follows the sheet is often the last one. A reading that
## drops an inset to zero is therefore held back until a later re-check
## confirms it; the last re-check is trusted as it is, so a real change
## (another device state, multitasking) still gets through.
const INSET_RECHECK_SECONDS: Array[float] = [0.5, 2.0]
## Window size the current re-check sequence was started for; a new
## sequence supersedes the pending timers of the old one.
var _inset_sequence: int = 0
var _inset_window_size: Vector2i = Vector2i.ZERO


func _ready() -> void:
	TranslationServer.set_locale(StatsStore.locale if not StatsStore.locale.is_empty() else DEFAULT_LOCALE)
	apply_theme(self, StatsStore.theme_name)
	get_tree().node_added.connect(_on_node_added)
	for scroll in find_children("*", "ScrollContainer", true, false):
		DragScroll.attach(scroll as ScrollContainer)
	StatsStore.theme_changed.connect(_on_theme_changed)
	_build_bars()
	SceneRouter.screen_changed.connect(_on_screen_changed)
	Layout.watch(self, _apply_scale)
	SceneRouter.attach(_host)
	if StatsStore.onboarding_done or not StatsStore.history.records.is_empty():
		SceneRouter.show_menu()
	else:
		SceneRouter.show_onboarding()


func _build_bars() -> void:
	_back_button.icon = _icon("nav_back")
	_back_button.pressed.connect(_on_back_pressed)
	_quit_button.icon = _icon("nav_quit")
	_quit_button.pressed.connect(get_tree().quit)
	_quit_button.visible = not OS.has_feature("web")
	# The title's box carries empty line spacing above the capitals; the row
	# gap is shorter by it, so the discs stand TOP_BAR_GAP from the caps.
	_top_rows.add_theme_constant_override("separation", roundi(TOP_BAR_GAP - Layout.caps_offset(_title_label)))
	var actions: Dictionary = {
		&"menu": SceneRouter.show_menu,
		&"training": SceneRouter.show_training,
		&"progress": SceneRouter.show_progress,
		&"profile": SceneRouter.show_profile,
		&"settings": SceneRouter.show_settings,
	}
	for item in NAV_ITEMS:
		var screen: StringName = item["screen"]
		var text_key: String = item["text"]
		var icon_name: String = item["icon"]
		var button := Button.new()
		button.theme_type_variation = &"NavButton"
		# The key itself, so a language switch in the settings re-translates it.
		button.text = text_key
		button.icon = _icon(icon_name)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var action: Callable = actions[screen]
		button.pressed.connect(func() -> void:
			if _screen == screen:
				button.button_pressed = true
			else:
				action.call())
		_nav_buttons.add_child(button)
		_tabs[screen] = button


func _on_back_pressed() -> void:
	if _screen == SceneRouter.DRILL_SETUP:
		SceneRouter.abort_drill()
	else:
		SceneRouter.show_menu()


func _on_screen_changed(screen: StringName) -> void:
	_screen = screen
	var drill_setup := screen == SceneRouter.DRILL_SETUP
	var chrome := TITLES.has(screen) or drill_setup
	_top_bar.visible = chrome
	_bottom_bar.visible = chrome
	_apply_insets()
	if not chrome:
		return
	# The label holds the key itself; a language switch re-translates it.
	var title_key: String = ""
	if drill_setup:
		if SceneRouter.current_drill != null and SceneRouter.current_drill.definition != null:
			title_key = SceneRouter.current_drill.definition.title_key
	else:
		title_key = TITLES[screen]
	_title_label.text = title_key
	_back_button.visible = not _tabs.has(screen)
	for id: StringName in _tabs:
		var button: Button = _tabs[id]
		button.button_pressed = id == screen
	_refresh_stats()


## Level, streak and today's minutes, refreshed on every screen change (a
## finished run changes them).
func _refresh_stats() -> void:
	for child in _top_stats.get_children():
		_top_stats.remove_child(child)
		child.queue_free()
	GamiWidgets.add_brief_stats(_top_stats, SceneRouter.show_profile)


## Max width of the bottom bar's tabs on a wide screen, in design units.
const NAV_MAX_WIDTH := 640.0
## Share of the home-indicator inset the bottom bar adds under its tabs.
## Zero on the maintainer's wish (2026-10-06): on the iPhone the page ends
## above the indicator anyway. Raise it (e.g. 0.3) if the tabs ever collide
## with the indicator once the canvas reaches the very bottom.
const BOTTOM_INSET_SHARE := 0.0
const BOTTOM_INSET_MAX := 12.0


func _apply_scale() -> void:
	Layout.apply_scale(get_tree().root)
	# App.resized also lands here (every inset change moves the App), so a
	# new re-check sequence starts only when the window itself changed.
	if get_tree().root.size != _inset_window_size:
		_inset_window_size = get_tree().root.size
		_schedule_inset_checks()
	# The tabs stay together in the middle of a wide window instead of
	# spreading across it; on a phone they take the bar's inner width.
	var bar_style := _bottom_bar.get_theme_stylebox("panel")
	var padding := bar_style.get_content_margin(SIDE_LEFT) + bar_style.get_content_margin(SIDE_RIGHT)
	_nav_buttons.custom_minimum_size.x = minf(Layout.viewport_width(self) - padding, NAV_MAX_WIDTH)


## Measures now (holding back drops to zero) and again after each delay in
## INSET_RECHECK_SECONDS, the last time trusting the reading; timers of an
## older sequence do nothing.
func _schedule_inset_checks() -> void:
	_inset_sequence += 1
	var sequence := _inset_sequence
	_measure_insets(false)
	for i in INSET_RECHECK_SECONDS.size():
		var trusted := i == INSET_RECHECK_SECONDS.size() - 1
		get_tree().create_timer(INSET_RECHECK_SECONDS[i]).timeout.connect(func() -> void:
			if sequence == _inset_sequence:
				_measure_insets(trusted))


## Reads the safe-area insets and applies them when they changed. Unless
## [param trusted], an inset that fell to zero keeps its previous value
## (a system sheet is probably up); a non-zero reading is always taken.
func _measure_insets(trusted: bool) -> void:
	var measured := Layout.safe_insets(get_tree().root)
	if not trusted:
		if measured.x == 0.0:
			measured.x = _insets.x
		if measured.y == 0.0:
			measured.y = _insets.y
	if measured != _insets:
		_insets = measured
		_apply_insets()


## Focus coming back (a sheet closed) starts a re-check sequence too.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_schedule_inset_checks()


## With the bars shown they reach the edges of the screen and grow their
## own padding by the notch and the home indicator, as native tab bars do;
## a screen without bars is inset as a whole instead.
func _apply_insets() -> void:
	var chrome := _top_bar.visible
	offset_top = 0.0 if chrome else _insets.x
	offset_bottom = 0.0 if chrome else -_insets.y
	# Below the title only the part of the gap its descent does not cover.
	_pad_bar(_top_bar, &"TopBar", TOP_BAR_GAP + _insets.x, TOP_BAR_GAP - _title_descent())
	_pad_bar(_bottom_bar, &"BottomBar", 0.0, minf(_insets.y * BOTTOM_INSET_SHARE, BOTTOM_INSET_MAX))


## Adds [param top] and [param bottom] to the bar's vertical content margins.
func _pad_bar(bar: PanelContainer, variation: StringName, top: float, bottom: float) -> void:
	bar.remove_theme_stylebox_override("panel")
	if top <= 0.0 and bottom <= 0.0:
		return
	var style := get_theme_stylebox("panel", variation).duplicate() as StyleBox
	style.content_margin_top += maxf(top, 0.0)
	style.content_margin_bottom += maxf(bottom, 0.0)
	bar.add_theme_stylebox_override("panel", style)


## Space the title's box keeps below its baseline.
func _title_descent() -> float:
	return _title_label.get_theme_font("font").get_descent(_title_label.get_theme_font_size("font_size"))


static func _icon(name: String) -> Texture2D:
	return load(ICON_DIR + name + ".svg") as Texture2D


## Every list scrolls by dragging, not only through its scrollbar.
func _on_node_added(node: Node) -> void:
	var scroll := node as ScrollContainer
	if scroll != null:
		DragScroll.attach(scroll)


func _on_theme_changed(name: String) -> void:
	apply_theme(self, name)
	_apply_insets()


## Loads ui/theme/<name>_theme.tres onto [param host] (every screen inherits it)
## and paints the window background with the theme's "bg" colour.
static func apply_theme(host: Control, name: String) -> void:
	var theme := load("res://ui/theme/%s_theme.tres" % name) as Theme
	if theme == null:
		push_warning("App: theme %s not found" % name)
		return
	host.theme = theme
	RenderingServer.set_default_clear_color(theme.get_color("bg", "App"))
