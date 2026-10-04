## Visual masking: a letter flashes and a mask covers it; pick the letter you saw.
extends TrialDrill

const GAP_SECONDS := 0.6

var _logic: MaskingLogic
var _stimulus: Label
var _buttons: Array[Button] = []
var _row: HBoxContainer
var _accepting: bool = false


func _trial_options() -> Array[int]:
	return [15, 25, 40]


func _default_trials() -> int:
	return 25


func _build_play_area(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	parent.add_child(vbox)
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(stage)
	_stimulus = _make_stimulus_label(stage, 140)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 12)
	_row.custom_minimum_size = Vector2(0, 110)
	vbox.add_child(_row)
	for i in MaskingLogic.OPTION_COUNT:
		var button := _make_pad("", 40)
		button.pressed.connect(_on_option_pressed.bind(i))
		_row.add_child(button)
		_buttons.append(button)
	_row.visible = false


func _handle_response(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not _accepting:
		return
	var typed := char(key.unicode).to_upper()
	var index := _logic.options.find(typed)
	if index < 0 and key.keycode >= KEY_1 and key.keycode <= KEY_4:
		index = key.keycode - KEY_1
	if index >= 0:
		_on_option_pressed(index)
		get_viewport().set_input_as_handled()


func _run_trials() -> void:
	_logic = MaskingLogic.new(trials, _rng)
	_next_trial()


func _next_trial() -> void:
	_accepting = false
	_row.visible = false
	_stimulus.text = "+"
	_stimulus.theme_type_variation = &"DimLabel"
	if not await _wait(GAP_SECONDS):
		return
	_logic.new_trial()
	_stimulus.theme_type_variation = &""
	_stimulus.text = _logic.target
	if not await _wait(_logic.exposure_ms() / 1000.0):
		return
	_stimulus.text = _logic.mask_text()
	if not await _wait(MaskingLogic.MASK_MS / 1000.0):
		return
	_stimulus.text = ""
	for i in _buttons.size():
		_buttons[i].text = _logic.options[i]
	_row.visible = true
	_set_progress_text("%d ms   %d / %d" % [roundi(_logic.exposure_ms()), _logic.current, trials])
	_accepting = true


func _on_option_pressed(index: int) -> void:
	if not _running or not _accepting:
		return
	_accepting = false
	var correct := _logic.answer(_logic.options[index])
	_flash_pad(_buttons[index], get_theme_color("correct" if correct else "wrong", "Pad"), 0.4)
	if not await _wait(0.4):
		return
	if _logic.is_done():
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_next_trial()
