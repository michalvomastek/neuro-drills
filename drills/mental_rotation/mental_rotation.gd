## Mental rotation: is the right shape the left one rotated, or its mirror image?
extends TrialDrill

const FEEDBACK_SECONDS := 0.5

var _logic: RotationLogic
var _reference: PolyominoView
var _probe: PolyominoView
var _buttons: Array[Button] = []
var _accepting: bool = false
var _stimulus_ms: int = 0


func _trial_options() -> Array[int]:
	return [12, 20, 30]


func _default_trials() -> int:
	return 12


func _build_play_area(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	parent.add_child(vbox)
	var shapes := HBoxContainer.new()
	shapes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shapes.add_theme_constant_override("separation", 48)
	vbox.add_child(shapes)
	_reference = PolyominoView.new()
	_reference.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reference.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shapes.add_child(_reference)
	_probe = PolyominoView.new()
	_probe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_probe.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_probe.color = get_theme_color("lit", "Board")
	shapes.add_child(_probe)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 100)
	vbox.add_child(row)
	var keys: Array[String] = ["ROTATION_SAME", "ROTATION_MIRROR"]
	for i in 2:
		var button := _make_pad(tr(keys[i]), 28)
		# Equal halves with wrapping labels, so the long "Same (rotated)"
		# does not push the second pad off a phone screen.
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.pressed.connect(_on_answer.bind(i == 0))
		row.add_child(button)
		_buttons.append(button)


func _handle_response(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_on_answer(true)
	elif event.is_action_pressed("ui_right"):
		_on_answer(false)
	else:
		return
	get_viewport().set_input_as_handled()


func _run_trials() -> void:
	_logic = RotationLogic.new(trials, _rng)
	_next_trial()


func _next_trial() -> void:
	_accepting = false
	_reference.set_cells([])
	_probe.set_cells([])
	if not await _wait(0.5):
		return
	_reference.set_cells(_logic.reference_cells())
	_probe.set_cells(_logic.probe_cells())
	_stimulus_ms = Time.get_ticks_msec()
	_accepting = true


func _on_answer(says_same: bool) -> void:
	if not _running or not _accepting:
		return
	_accepting = false
	var correct := _logic.answer(says_same, Time.get_ticks_msec() - _stimulus_ms)
	_flash_pad(_buttons[0 if says_same else 1], get_theme_color("correct" if correct else "wrong", "Pad"), FEEDBACK_SECONDS)
	_set_progress(_logic.current)
	if not await _wait(FEEDBACK_SECONDS):
		return
	if _logic.is_done():
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_next_trial()
