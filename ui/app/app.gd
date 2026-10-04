## Main scene: hosts the current screen and hands navigation to SceneRouter.
extends Control

const DEFAULT_LOCALE := "cs"


func _ready() -> void:
	TranslationServer.set_locale(DEFAULT_LOCALE)
	SceneRouter.attach(self)
	SceneRouter.show_menu()
