## Optokinetic stripes: keep your eyes on the centre digit while stripes stream
## past; press space or click each time the digit changes.
extends TrialDrill

const SPEEDS: Array[int] = [1, 2, 3]
const DEFAULT_SPEED := 2

var _speed: int = DEFAULT_SPEED
var _speed_option: OptionButton
var _logic: OknLogic
var _pad: Button
var _stripes: ColorRect
var _material: ShaderMaterial
var _digit: Label
var _digit_value: int = 5
var _window_open: bool = false
var _stimulus_ms: int = 0


func _trial_options() -> Array[int]:
	return [10, 15, 25]


func _default_trials() -> int:
	return 10


func _build_extras(parent: VBoxContainer) -> void:
	_speed_option = _add_option_row(parent, "OKN_SPEED", SPEEDS, _speed)


func _apply_extra_config(config: Dictionary) -> void:
	var requested: int = config.get("speed", DEFAULT_SPEED)
	if SPEEDS.has(requested):
		_speed = requested
	_speed_option.select(_speed_option.get_item_index(_speed))


func _collect_extra_config() -> Dictionary:
	return {"speed": _speed}


func _on_start_pressed() -> void:
	_speed = _speed_option.get_selected_id()
	super()


func _build_play_area(parent: Control) -> void:
	_pad = _make_pad()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.pressed.connect(_on_response)
	parent.add_child(_pad)
	_stripes = ColorRect.new()
	_stripes.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stripes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load("res://drills/okn_stripes/stripes.gdshader") as Shader
	_stripes.material = _material
	parent.add_child(_stripes)
	var backdrop := Panel.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_preset(Control.PRESET_CENTER)
	backdrop.custom_minimum_size = Vector2(120, 120)
	backdrop.position = Vector2(-60, -60)
	backdrop.size = Vector2(120, 120)
	var style := StyleBoxFlat.new()
	style.bg_color = get_theme_color("cell", "Board")
	style.set_corner_radius_all(60)
	backdrop.add_theme_stylebox_override("panel", style)
	parent.add_child(backdrop)
	_digit = _make_stimulus_label(parent, 64)


func _handle_response(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_response()
		get_viewport().set_input_as_handled()


func _reset_play_state() -> void:
	_window_open = false


func _run_trials() -> void:
	_logic = OknLogic.new(trials, _rng)
	_material.set_shader_parameter("speed", 0.12 * _speed)
	_digit.text = str(_digit_value)
	if not await _wait(1.5):
		return
	for i in trials:
		if not await _wait(_logic.next_gap_ms() / 1000.0):
			return
		_digit_value = _logic.next_digit(_digit_value)
		_digit.text = str(_digit_value)
		_window_open = true
		_stimulus_ms = Time.get_ticks_msec()
		if not await _wait(OknLogic.RESPONSE_WINDOW_MS / 1000.0):
			return
		_window_open = false
		_logic.close_window()
		_set_progress(i + 1)
	_complete(_logic.build_result(definition.id, get_config()))


func _on_response() -> void:
	if not _running:
		return
	if _window_open:
		if _logic.respond(Time.get_ticks_msec() - _stimulus_ms):
			_flash_pad(_pad, get_theme_color("correct", "Pad"), 0.2)
	else:
		_logic.respond_outside_window()
