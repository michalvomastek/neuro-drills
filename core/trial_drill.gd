## Base for drills made of repeated trials. Builds the setup panel (trial
## count, countdown, drill-specific extras), the play frame with a progress
## label and the countdown, and offers cancellable waits. Subclasses fill the
## play area, react to input in _handle_response() and drive the trial loop
## from _run_trials(), finishing with _complete().
class_name TrialDrill
extends Drill

const COUNTDOWN_FROM := 3
const PAD_STATES: Array[StringName] = [&"normal", &"hover", &"pressed"]
const MARGIN_SIDES: Array[StringName] = [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]

var trials: int = 20
var countdown: bool = true

var _run_token: int = 0
var _running: bool = false
var _rng := RandomNumberGenerator.new()

var _setup_panel: CenterContainer
var _title_label: Label
var _description_label: Label
var _trials_option: OptionButton
var _countdown_check: CheckBox
var _extras_box: VBoxContainer
var _start_button: Button
var _play_panel: MarginContainer
var _play_area: Control
var _progress_label: Label
var _countdown_panel: CenterContainer
var _countdown_label: Label


func _ready() -> void:
	_rng.randomize()
	trials = _default_trials()
	_build_ui()
	_build_play_area(_play_area)
	_show_setup()


# --- hooks for subclasses -------------------------------------------------

## Selectable trial counts for the setup panel.
func _trial_options() -> Array[int]:
	return [10, 20, 30]


func _default_trials() -> int:
	return 20


## Add drill-specific setup controls here.
func _build_extras(_parent: VBoxContainer) -> void:
	pass


## Build the stimulus and response controls inside [param parent] (full-rect Control).
func _build_play_area(_parent: Control) -> void:
	pass


func _apply_extra_config(_config: Dictionary) -> void:
	pass


func _collect_extra_config() -> Dictionary:
	return {}


## Starts the trial loop; the drill is running and the play panel is visible.
func _run_trials() -> void:
	pass


## Keyboard or other input while running; mouse input usually arrives through buttons.
func _handle_response(_event: InputEvent) -> void:
	pass


# --- lifecycle -------------------------------------------------------------

func _on_setup(config: Dictionary, autostart: bool) -> void:
	_title_label.text = tr(definition.title_key)
	_description_label.text = tr(definition.description_key)
	var requested: int = config.get("trials", _default_trials())
	if _trial_options().has(requested):
		trials = requested
	countdown = config.get("countdown", true)
	_apply_extra_config(config)
	_trials_option.select(_trials_option.get_item_index(trials))
	_countdown_check.button_pressed = countdown
	if autostart:
		_begin_run()
	else:
		_show_setup()


func get_config() -> Dictionary:
	var config := {"trials": trials, "countdown": countdown}
	config.merge(_collect_extra_config())
	return config


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _setup_panel.visible:
			aborted.emit()
		else:
			_show_setup()
		get_viewport().set_input_as_handled()
		return
	if _running:
		_handle_response(event)


func _show_setup() -> void:
	_run_token += 1
	_running = false
	_setup_panel.visible = true
	_play_panel.visible = false
	_countdown_panel.visible = false
	_start_button.grab_focus()


func _on_start_pressed() -> void:
	trials = _trials_option.get_selected_id()
	countdown = _countdown_check.button_pressed
	_begin_run()


func _begin_run() -> void:
	_run_token += 1
	_running = false
	_setup_panel.visible = false
	_play_panel.visible = false
	if countdown:
		_countdown_panel.visible = true
		for i in range(COUNTDOWN_FROM, 0, -1):
			_countdown_label.text = str(i)
			if not await _wait(1.0):
				return
		_countdown_panel.visible = false
	_play_panel.visible = true
	_running = true
	_set_progress(0)
	_run_trials()


## Waits and tells whether the run is still the same one afterwards.
func _wait(seconds: float) -> bool:
	var token := _run_token
	await get_tree().create_timer(seconds).timeout
	return token == _run_token and is_inside_tree() and _running


func _set_progress(done: int) -> void:
	_progress_label.text = "%d / %d" % [done, trials]


func _complete(result: DrillResult) -> void:
	_run_token += 1
	_running = false
	finished.emit(result)


# --- UI construction ---------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_setup_panel = CenterContainer.new()
	_setup_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_setup_panel)
	var panel := PanelContainer.new()
	_setup_panel.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(560, 0)
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(_title_label)
	_description_label = Label.new()
	_description_label.theme_type_variation = &"DimLabel"
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_description_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)
	var trials_label := Label.new()
	trials_label.text = tr("TRIAL_COUNT")
	trials_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(trials_label)
	_trials_option = OptionButton.new()
	for option in _trial_options():
		_trials_option.add_item(str(option), option)
	_trials_option.select(_trials_option.get_item_index(trials))
	row.add_child(_trials_option)

	_countdown_check = CheckBox.new()
	_countdown_check.text = tr("OPT_COUNTDOWN")
	_countdown_check.button_pressed = countdown
	vbox.add_child(_countdown_check)

	_extras_box = VBoxContainer.new()
	_extras_box.add_theme_constant_override("separation", 12)
	vbox.add_child(_extras_box)
	_build_extras(_extras_box)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	vbox.add_child(buttons)
	var back_button := Button.new()
	back_button.text = tr("COMMON_BACK")
	back_button.pressed.connect(aborted.emit)
	buttons.add_child(back_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	_start_button = Button.new()
	_start_button.text = tr("COMMON_START")
	_start_button.theme_type_variation = &"PrimaryButton"
	_start_button.pressed.connect(_on_start_pressed)
	buttons.add_child(_start_button)

	_play_panel = MarginContainer.new()
	_play_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in MARGIN_SIDES:
		_play_panel.add_theme_constant_override(side, 16)
	_play_panel.visible = false
	add_child(_play_panel)
	var play_vbox := VBoxContainer.new()
	play_vbox.add_theme_constant_override("separation", 8)
	_play_panel.add_child(play_vbox)
	var top_bar := HBoxContainer.new()
	play_vbox.add_child(top_bar)
	var play_back := Button.new()
	play_back.text = tr("COMMON_BACK")
	play_back.focus_mode = Control.FOCUS_NONE
	play_back.pressed.connect(_show_setup)
	top_bar.add_child(play_back)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_spacer)
	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 28)
	top_bar.add_child(_progress_label)
	_play_area = Control.new()
	_play_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_vbox.add_child(_play_area)

	_countdown_panel = CenterContainer.new()
	_countdown_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_countdown_panel.visible = false
	add_child(_countdown_panel)
	_countdown_label = Label.new()
	_countdown_label.add_theme_font_size_override("font_size", 140)
	_countdown_panel.add_child(_countdown_label)


## A large flat button that fires on press, used as a response pad or stimulus surface.
func _make_pad(text: String = "", font_size: int = 48) -> Button:
	var pad := Button.new()
	pad.text = text
	pad.theme_type_variation = &"Pad"
	pad.focus_mode = Control.FOCUS_NONE
	pad.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	pad.add_theme_font_size_override("font_size", font_size)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return pad


## Fills [param parent] with two side-by-side pads (index 0 left, 1 right).
func _make_side_pads(parent: Control) -> Array[Button]:
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 12)
	parent.add_child(box)
	var pads: Array[Button] = [_make_pad("◀", 64), _make_pad("▶", 64)]
	for pad in pads:
		box.add_child(pad)
	return pads


## A big centred label laid over the play area that ignores the mouse.
func _make_stimulus_label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


## Recolours a pad until _clear_pad_flash() is called.
func _set_pad_color(pad: Button, color: Color) -> StyleBoxFlat:
	var base := get_theme_stylebox("normal", "Pad") as StyleBoxFlat
	var style := base.duplicate() as StyleBoxFlat
	style.bg_color = color
	for state in PAD_STATES:
		pad.add_theme_stylebox_override(state, style)
	return style


## Temporarily recolours a pad and fades it back, like the Schulte flash.
func _flash_pad(pad: Button, color: Color, fade_seconds: float = 0.4) -> void:
	var base := get_theme_stylebox("normal", "Pad") as StyleBoxFlat
	var style := _set_pad_color(pad, color)
	var tween := pad.create_tween()
	tween.tween_property(style, "bg_color", base.bg_color, fade_seconds)
	tween.tween_callback(_clear_pad_flash.bind(pad))


func _clear_pad_flash(pad: Button) -> void:
	for state in PAD_STATES:
		pad.remove_theme_stylebox_override(state)
