## 3D mental rotation: two cube figures turn slowly; is the right one the left
## one rotated, or its mirror image?
extends TrialDrill

const FEEDBACK_SECONDS := 0.5
const SPIN_SPEED := 0.5

var _logic: Rotation3DLogic
var _scenes: Array[Scene3D] = []
var _figures: Array[Node3D] = []
var _buttons: Array[Button] = []
var _accepting: bool = false
var _stimulus_ms: int = 0


func _trial_options() -> Array[int]:
	return [10, 16, 24]


func _default_trials() -> int:
	return 10


func _build_play_area(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	parent.add_child(vbox)
	var views := HBoxContainer.new()
	views.size_flags_vertical = Control.SIZE_EXPAND_FILL
	views.add_theme_constant_override("separation", 24)
	vbox.add_child(views)
	for i in 2:
		var holder := Control.new()
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		holder.clip_contents = true
		views.add_child(holder)
		var scene := Scene3D.new(holder)
		scene.camera.position = Vector3(0, 2.0, 9.0)
		scene.camera.look_at(Vector3.ZERO)
		_scenes.append(scene)
		var figure := Node3D.new()
		scene.world.add_child(figure)
		_figures.append(figure)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 90)
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


func _process(delta: float) -> void:
	if not _running:
		return
	for figure in _figures:
		figure.rotate_y(SPIN_SPEED * delta)


func _run_trials() -> void:
	_logic = Rotation3DLogic.new(trials, _rng)
	_next_trial()


func _build_figure(holder: Node3D, cubes: Array[Vector3i], color: Color, rotation: Vector3) -> void:
	for child in holder.get_children():
		child.queue_free()
	var centre := Vector3.ZERO
	for c in cubes:
		centre += Vector3(c)
	centre /= cubes.size()
	var body := Node3D.new()
	body.rotation = rotation
	holder.add_child(body)
	for c in cubes:
		var cube := Scene3D.make_box(Vector3(0.95, 0.95, 0.95), color)
		cube.position = Vector3(c) - centre
		body.add_child(cube)


func _next_trial() -> void:
	_accepting = false
	if not await _wait(0.4):
		return
	_build_figure(_figures[0], _logic.reference_cubes(), Color(0.9, 0.9, 0.93), Vector3.ZERO)
	_build_figure(_figures[1], _logic.probe_cubes(), get_theme_color("lit", "Board"), _logic.probe_rotation())
	_figures[0].rotation = Vector3.ZERO
	_figures[1].rotation = Vector3.ZERO
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


func _reset_play_state() -> void:
	_accepting = false
