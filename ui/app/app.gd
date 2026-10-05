## Main scene: a fixed top bar (screen title, streak and daily goal, feedback,
## quit), the host of the current screen and a fixed bottom bar with the five
## main destinations. The bars show on the top-level screens only; a drill,
## the results, a training brief or the onboarding take the whole window.
extends Control

const DEFAULT_LOCALE := "cs"
const ICON_DIR := "res://assets/icons/"

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
@onready var _bottom_bar: PanelContainer = %BottomBar
@onready var _host: Control = %Host
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _top_stats: HBoxContainer = %TopStats
@onready var _feedback_button: Button = %FeedbackButton
@onready var _quit_button: Button = %QuitButton
@onready var _nav_buttons: HBoxContainer = %NavButtons

var _screen: StringName = &""
var _tabs: Dictionary = {}


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
	_back_button.pressed.connect(SceneRouter.show_menu)
	_feedback_button.icon = _icon("nav_feedback")
	_feedback_button.pressed.connect(SceneRouter.show_feedback)
	_quit_button.icon = _icon("nav_quit")
	_quit_button.pressed.connect(get_tree().quit)
	_quit_button.visible = not OS.has_feature("web")
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
		button.text = tr(text_key)
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


func _on_screen_changed(screen: StringName) -> void:
	_screen = screen
	var chrome := TITLES.has(screen)
	_top_bar.visible = chrome
	_bottom_bar.visible = chrome
	if not chrome:
		return
	var title_key: String = TITLES[screen]
	_title_label.text = tr(title_key)
	_back_button.visible = not _tabs.has(screen)
	for id: StringName in _tabs:
		var button: Button = _tabs[id]
		button.button_pressed = id == screen
	_refresh_stats()


## Streak and today's minutes, refreshed on every screen change (a finished
## run changes them) and on resize (the phone gets the short wording).
func _refresh_stats() -> void:
	for child in _top_stats.get_children():
		_top_stats.remove_child(child)
		child.queue_free()
	GamiWidgets.add_brief_stats(_top_stats, Layout.is_narrow(self))


## Max width of the bottom bar's tabs on a wide screen, in design units.
const NAV_MAX_WIDTH := 640.0


func _apply_scale() -> void:
	Layout.apply_scale(get_tree().root)
	var insets := Layout.safe_insets(get_tree().root)
	offset_top = insets.x
	offset_bottom = -insets.y
	# The tabs stay together in the middle of a wide window instead of
	# spreading across it.
	_nav_buttons.custom_minimum_size.x = minf(Layout.viewport_width(self), NAV_MAX_WIDTH)
	_title_label.add_theme_font_size_override("font_size", 20 if Layout.is_narrow(self) else 24)
	if _top_bar.visible:
		_refresh_stats()


static func _icon(name: String) -> Texture2D:
	return load(ICON_DIR + name + ".svg") as Texture2D


## Every list scrolls by dragging, not only through its scrollbar.
func _on_node_added(node: Node) -> void:
	var scroll := node as ScrollContainer
	if scroll != null:
		DragScroll.attach(scroll)


func _on_theme_changed(name: String) -> void:
	apply_theme(self, name)


## Loads ui/theme/<name>_theme.tres onto [param host] (every screen inherits it)
## and paints the window background with the theme's "bg" colour.
static func apply_theme(host: Control, name: String) -> void:
	var theme := load("res://ui/theme/%s_theme.tres" % name) as Theme
	if theme == null:
		push_warning("App: theme %s not found" % name)
		return
	host.theme = theme
	RenderingServer.set_default_clear_color(theme.get_color("bg", "App"))
