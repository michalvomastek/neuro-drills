## One place for the app-wide preferences: language, theme, text size,
## exertion question, sounds; plus the way to the data screens and deleting
## the history. Every change applies at once and is persisted by StatsStore.
class_name SettingsScreen
extends Control

const LOCALES: Array[String] = ["cs", "en"]
const LOCALE_KEYS: Array[String] = ["SETTINGS_LANGUAGE_CS", "SETTINGS_LANGUAGE_EN"]
const THEMES: Array[String] = ["dark", "light"]
const THEME_KEYS: Array[String] = ["SETTINGS_THEME_DARK", "SETTINGS_THEME_LIGHT"]
const TEXT_SCALES: Array[float] = [0.9, 1.0, 1.15]
const TEXT_SCALE_KEYS: Array[String] = ["SETTINGS_TEXT_SMALL", "SETTINGS_TEXT_NORMAL", "SETTINGS_TEXT_LARGE"]

@onready var _vbox: VBoxContainer = %VBox
@onready var _rows: GridContainer = %Rows
@onready var _back_button: Button = %BackButton
@onready var _progress_button: Button = %ProgressButton
@onready var _feedback_button: Button = %FeedbackButton
@onready var _clear_button: Button = %ClearButton
@onready var _clear_dialog: ConfirmationDialog = %ClearDialog


func _ready() -> void:
	_back_button.pressed.connect(SceneRouter.show_menu)
	_progress_button.pressed.connect(SceneRouter.show_progress)
	_feedback_button.pressed.connect(SceneRouter.show_feedback)
	_clear_button.pressed.connect(_clear_dialog.popup_centered)
	_clear_dialog.confirmed.connect(_on_clear_confirmed)
	_clear_dialog.ok_button_text = tr("PROGRESS_CLEAR")
	_clear_dialog.cancel_button_text = tr("COMMON_BACK")
	_clear_button.disabled = StatsStore.history.records.is_empty()
	_add_option("SETTINGS_LANGUAGE", LOCALE_KEYS, LOCALES.find(StatsStore.locale), _on_language_selected)
	_add_option("SETTINGS_THEME", THEME_KEYS, THEMES.find(StatsStore.theme_name), _on_theme_selected)
	_add_option("SETTINGS_TEXT_SIZE", TEXT_SCALE_KEYS, _text_scale_index(), _on_text_scale_selected)
	_add_toggle("SETTINGS_SOUND", StatsStore.sound_enabled, StatsStore.set_sound_enabled)
	_add_toggle("PROGRESS_RPE_ENABLED", StatsStore.rpe_enabled, StatsStore.set_rpe_enabled)
	Layout.watch(self, _relayout)
	_back_button.grab_focus()


func _relayout() -> void:
	_vbox.custom_minimum_size = Vector2(Layout.panel_width(self, 520.0), 0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneRouter.show_menu()
		get_viewport().set_input_as_handled()


func _add_option(label_key: String, item_keys: Array[String], selected: int, on_selected: Callable) -> void:
	_add_label(label_key)
	var option := OptionButton.new()
	for key in item_keys:
		option.add_item(tr(key))
	option.select(maxi(0, selected))
	option.item_selected.connect(on_selected)
	option.size_flags_horizontal = Control.SIZE_SHRINK_END
	_rows.add_child(option)


func _add_toggle(label_key: String, on: bool, on_toggled: Callable) -> void:
	_add_label(label_key)
	var check := CheckButton.new()
	check.button_pressed = on
	check.toggled.connect(on_toggled)
	check.size_flags_horizontal = Control.SIZE_SHRINK_END
	_rows.add_child(check)


func _add_label(label_key: String) -> void:
	var label := Label.new()
	label.text = tr(label_key)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rows.add_child(label)


func _text_scale_index() -> int:
	var best := 1
	for i in TEXT_SCALES.size():
		if absf(TEXT_SCALES[i] - StatsStore.text_scale) < absf(TEXT_SCALES[best] - StatsStore.text_scale):
			best = i
	return best


func _on_language_selected(index: int) -> void:
	StatsStore.set_locale(LOCALES[index])
	# Texts set from code do not retranslate on their own; rebuild the screen.
	SceneRouter.show_settings()


func _on_theme_selected(index: int) -> void:
	StatsStore.set_theme_name(THEMES[index])


func _on_text_scale_selected(index: int) -> void:
	StatsStore.set_text_scale(TEXT_SCALES[index])


func _on_clear_confirmed() -> void:
	StatsStore.clear()
	_clear_button.disabled = true
