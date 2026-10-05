## Main scene: hosts the current screen and hands navigation to SceneRouter.
extends Control

const DEFAULT_LOCALE := "cs"


func _ready() -> void:
	TranslationServer.set_locale(StatsStore.locale if not StatsStore.locale.is_empty() else DEFAULT_LOCALE)
	apply_theme(self, StatsStore.theme_name)
	get_tree().node_added.connect(_on_node_added)
	for scroll in find_children("*", "ScrollContainer", true, false):
		DragScroll.attach(scroll as ScrollContainer)
	StatsStore.theme_changed.connect(_on_theme_changed)
	Layout.watch(self, _apply_scale)
	SceneRouter.attach(self)
	if StatsStore.onboarding_done or not StatsStore.history.records.is_empty():
		SceneRouter.show_menu()
	else:
		SceneRouter.show_onboarding()


func _apply_scale() -> void:
	Layout.apply_scale(get_tree().root)
	var insets := Layout.safe_insets(get_tree().root)
	offset_top = insets.x
	offset_bottom = -insets.y


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
