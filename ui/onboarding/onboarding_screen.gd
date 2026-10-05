## Three short pages for the first start: what the drills are, how the
## training works, where the data lives. Ends in a five-minute first training
## or in the menu; reachable again from the settings.
class_name OnboardingScreen
extends Control

const FIRST_TRAINING_MINUTES := 5
const PAGES: Array[String] = ["ONBOARDING_1", "ONBOARDING_2", "ONBOARDING_3"]

@onready var _vbox: VBoxContainer = %VBox
@onready var _step_label: Label = %StepLabel
@onready var _title_label: Label = %TitleLabel
@onready var _body_label: Label = %BodyLabel
@onready var _dots: HBoxContainer = %Dots
@onready var _skip_button: Button = %SkipButton
@onready var _menu_button: Button = %MenuButton
@onready var _next_button: Button = %NextButton
@onready var _spacer: Control = %Spacer

var _page: int = 0


func _ready() -> void:
	_skip_button.pressed.connect(_finish.bind(false))
	_menu_button.pressed.connect(_finish.bind(false))
	_next_button.pressed.connect(_on_next_pressed)
	for i in PAGES.size():
		var dot := PanelContainer.new()
		dot.custom_minimum_size = Vector2(12, 12)
		_dots.add_child(dot)
	Layout.watch(self, _relayout)
	_show_page(0)


func _relayout() -> void:
	_vbox.custom_minimum_size = Vector2(Layout.panel_width(self, 560.0), 0)
	_spacer.visible = not Layout.is_narrow(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_finish(false)
		get_viewport().set_input_as_handled()


func _show_page(index: int) -> void:
	_page = index
	var last := index == PAGES.size() - 1
	_step_label.text = tr("ONBOARDING_STEP") % [index + 1, PAGES.size()]
	_title_label.text = tr(PAGES[index] + "_TITLE")
	_body_label.text = tr(PAGES[index] + "_BODY")
	for i in _dots.get_child_count():
		var dot := _dots.get_child(i) as PanelContainer
		dot.theme_type_variation = &"GoalPill" if i == index else &"Pill"
	_skip_button.visible = not last
	_menu_button.visible = last
	_next_button.text = tr("ONBOARDING_START_TRAINING" if last else "ONBOARDING_NEXT")
	_next_button.grab_focus()


func _on_next_pressed() -> void:
	if _page < PAGES.size() - 1:
		_show_page(_page + 1)
	else:
		_finish(true)


## Marks the introduction as seen; [param start_training] opens a short first
## training without touching the saved training length (the introduction can
## be reopened from the settings).
func _finish(start_training: bool) -> void:
	StatsStore.set_onboarding_done(true)
	if start_training:
		SceneRouter.start_suggested_training(FIRST_TRAINING_MINUTES)
	else:
		SceneRouter.show_menu()
