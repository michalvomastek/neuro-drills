## Main scene: hosts the current screen and hands navigation to SceneRouter.
extends Control

const DEFAULT_LOCALE := "cs"


func _ready() -> void:
	TranslationServer.set_locale(DEFAULT_LOCALE)
	Layout.watch(self, _apply_scale)
	SceneRouter.attach(self)
	SceneRouter.show_menu()


func _apply_scale() -> void:
	Layout.apply_scale(get_tree().root)
