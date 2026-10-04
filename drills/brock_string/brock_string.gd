## Brock string in 3D: a string runs away from you with three beads on it.
## The highlighted bead shows a letter; read it and pick it below. Only the
## cued bead is sharp, the other letters are faded.
extends TrialDrill

const FEEDBACK_SECONDS := 0.4

var _logic: BrockLogic
var _scene: Scene3D
var _beads: Array[MeshInstance3D] = []
var _labels: Array[Label3D] = []
var _rings: Array[MeshInstance3D] = []
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
	vbox.add_theme_constant_override("separation", 12)
	parent.add_child(vbox)
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(stage)
	_scene = Scene3D.new(stage)
	# Above the string and looking down along it, so the beads line up vertically.
	_scene.camera.position = Vector3(0, 1.6, 0.9)
	_scene.camera.look_at(Vector3(0, -0.15, -4.5))
	_scene.camera.fov = 50.0
	var string_mesh := Scene3D.make_box(Vector3(0.02, 0.02, 12.0), Color(0.75, 0.75, 0.8))
	string_mesh.position = Vector3(0, -0.15, -6.0)
	_scene.world.add_child(string_mesh)
	var colors: Array[Color] = [Color(0.9, 0.3, 0.3), Color(0.95, 0.8, 0.25), Color(0.3, 0.65, 0.95)]
	for i in BrockLogic.DEPTHS.size():
		var bead := Scene3D.make_sphere(0.22, colors[i])
		bead.position = Vector3(0, -0.15, BrockLogic.DEPTHS[i])
		_scene.world.add_child(bead)
		_beads.append(bead)
		var ring := Scene3D.make_sphere(0.3, Color(1, 1, 1, 0.35))
		var ring_material := ring.material_override as StandardMaterial3D
		ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_material.albedo_color = Color(1, 1, 1, 0.3)
		ring.position = bead.position
		ring.visible = false
		_scene.world.add_child(ring)
		_rings.append(ring)
		var label := Label3D.new()
		label.position = bead.position + Vector3(0.55, 0.15, 0)
		label.font_size = 96
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 8
		_scene.world.add_child(label)
		_labels.append(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 90)
	vbox.add_child(row)
	for i in BrockLogic.OPTION_COUNT:
		var button := _make_pad("", 36)
		button.pressed.connect(_on_option_pressed.bind(i))
		row.add_child(button)
		_buttons.append(button)


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
	_logic = BrockLogic.new(trials, _rng)
	_next_trial()


func _next_trial() -> void:
	_accepting = false
	for i in _labels.size():
		_labels[i].text = ""
		_rings[i].visible = false
	if not await _wait(0.6):
		return
	_logic.new_trial()
	var cued := _logic.current_bead()
	for i in _labels.size():
		_labels[i].text = _logic.letter_on(i)
		_labels[i].modulate = Color(1, 1, 1, 1.0 if i == cued else 0.3)
		_rings[i].visible = i == cued
	for i in _buttons.size():
		_buttons[i].text = _logic.options[i]
	_stimulus_ms = Time.get_ticks_msec()
	_accepting = true


func _on_option_pressed(index: int) -> void:
	if not _running or not _accepting:
		return
	_accepting = false
	var correct := _logic.answer(_logic.options[index], Time.get_ticks_msec() - _stimulus_ms)
	_flash_pad(_buttons[index], get_theme_color("correct" if correct else "wrong", "Pad"), FEEDBACK_SECONDS)
	_set_progress(_logic.current)
	if not await _wait(FEEDBACK_SECONDS):
		return
	if _logic.is_done():
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_next_trial()


func _reset_play_state() -> void:
	_accepting = false
