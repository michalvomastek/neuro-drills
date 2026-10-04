## Contrast sensitivity: a faint striped patch appears; which way do the
## stripes run? Contrast drops after each correct answer.
extends TrialDrill

const SHOW_SECONDS := 0.8
const PATCH_SIZE := 320.0
const LABELS: Array[String] = ["│", "╱", "─", "╲"]

var _logic: ContrastLogic
var _patch: ColorRect
var _material: ShaderMaterial
var _buttons: Array[Button] = []
var _accepting: bool = false


func _trial_options() -> Array[int]:
	return [20, 30, 40]


func _default_trials() -> int:
	return 20


func _build_play_area(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	parent.add_child(vbox)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(center)
	_patch = ColorRect.new()
	_patch.custom_minimum_size = Vector2(PATCH_SIZE, PATCH_SIZE)
	_material = ShaderMaterial.new()
	_material.shader = load("res://drills/contrast_sensitivity/gabor.gdshader") as Shader
	_patch.material = _material
	center.add_child(_patch)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 100)
	vbox.add_child(row)
	for i in LABELS.size():
		var button := _make_pad(LABELS[i], 40)
		button.pressed.connect(_on_answer.bind(i))
		row.add_child(button)
		_buttons.append(button)


func _handle_response(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_4:
		_on_answer(key.keycode - KEY_1)
		get_viewport().set_input_as_handled()


func _run_trials() -> void:
	_logic = ContrastLogic.new(trials, _rng)
	_next_trial()


func _next_trial() -> void:
	_accepting = false
	_material.set_shader_parameter("contrast", 0.0)
	_set_progress_text("%s %d %%   %d / %d" % [tr("CONTRAST_LABEL"), roundi(_logic.contrast() * 100.0), _logic.current, trials])
	if not await _wait(0.6):
		return
	_logic.new_trial()
	_material.set_shader_parameter("orientation", _logic.orientation_radians())
	_material.set_shader_parameter("contrast", _logic.contrast())
	if not await _wait(SHOW_SECONDS):
		return
	_material.set_shader_parameter("contrast", 0.0)
	_accepting = true


func _on_answer(index: int) -> void:
	if not _running or not _accepting:
		return
	_accepting = false
	var correct := _logic.answer(index)
	_flash_pad(_buttons[index], get_theme_color("correct" if correct else "wrong", "Pad"), 0.4)
	if not await _wait(0.4):
		return
	if _logic.is_done():
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_next_trial()
