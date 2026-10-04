## Optic flow with looming obstacles: streaks rush past as if you were moving
## forward; when an obstacle swells towards you, tilt the device (or use the
## arrow keys / mouse) to steer out of its way.
extends TrialDrill

const TILT_GAIN := 0.9
const KEY_SPEED := 0.5
const MOUSE_GAIN := 0.0012
const MAX_SHIFT := 0.35

var _logic: LoomingLogic
var _flow: ColorRect
var _obstacle: Panel
var _obstacle_style: StyleBoxFlat
var _crosshair: Label
var _hint: Label
var _shift := Vector2.ZERO
var _started_ms: int = 0
var _first_move_ms: int = -1
var _active: bool = false
var _uses_tilt: bool = false
var _tilt_rest := Vector3.ZERO
var _last_pointer := Vector2.ZERO


func _trial_options() -> Array[int]:
	return [8, 12, 20]


func _default_trials() -> int:
	return 8


func _build_play_area(parent: Control) -> void:
	_flow = ColorRect.new()
	_flow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://drills/optic_flow/flow.gdshader") as Shader
	_flow.material = material
	parent.add_child(_flow)
	_obstacle = Panel.new()
	_obstacle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obstacle_style = StyleBoxFlat.new()
	_obstacle_style.bg_color = get_theme_color("wrong", "Pad")
	_obstacle.add_theme_stylebox_override("panel", _obstacle_style)
	_obstacle.visible = false
	parent.add_child(_obstacle)
	_crosshair = _make_stimulus_label(parent, 40)
	_crosshair.text = "+"
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.theme_type_variation = &"DimLabel"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.offset_top = -40
	parent.add_child(_hint)
	_uses_tilt = OS.has_feature("mobile") and Input.get_gravity().length() > 0.1


func _process(delta: float) -> void:
	if not _running:
		return
	var input := Vector2.ZERO
	if _uses_tilt:
		var gravity := Input.get_gravity() - _tilt_rest
		input = Vector2(gravity.x, -gravity.y) / 9.81 * TILT_GAIN
		_shift = (_shift + input * delta * 3.0).limit_length(MAX_SHIFT)
	else:
		var keys := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var pointer := get_local_mouse_position()
		var pointer_delta := pointer - _last_pointer
		_last_pointer = pointer
		if pointer_delta.length() > 40.0:
			pointer_delta = Vector2.ZERO
		input = keys * KEY_SPEED * delta + pointer_delta * MOUSE_GAIN
		_shift = (_shift + input).limit_length(MAX_SHIFT)
	if _active:
		if _first_move_ms < 0 and input.length() > 0.0005:
			_first_move_ms = Time.get_ticks_msec() - _started_ms
		var seconds := (Time.get_ticks_msec() - _started_ms) / 1000.0
		var radius := _logic.radius_at(seconds)
		var height := _flow.size.y
		var centre := _flow.size * 0.5 + (_logic.current_offset() - _shift) * height
		_obstacle.size = Vector2.ONE * radius * 2.0 * height
		_obstacle_style.set_corner_radius_all(roundi(radius * height))
		_obstacle.position = centre - _obstacle.size * 0.5
		if seconds >= LoomingLogic.GROW_SECONDS:
			_active = false
			var evaded := LoomingLogic.misses(_logic.current_offset(), _shift, radius)
			_obstacle_style.bg_color = get_theme_color("correct" if evaded else "wrong", "Pad")
			_logic.record(evaded, _first_move_ms)
			_set_progress(_logic.current)
			_after_trial()
	# The crosshair shows the steering offset.
	_crosshair.position = _shift * _flow.size.y * 0.5


func _run_trials() -> void:
	_logic = LoomingLogic.new(trials, _rng)
	_tilt_rest = Input.get_gravity()
	_shift = Vector2.ZERO
	_last_pointer = get_local_mouse_position()
	_hint.text = tr("LOOMING_HINT_TILT") if _uses_tilt else tr("LOOMING_HINT_KEYS")
	_next_trial()


func _next_trial() -> void:
	_active = false
	_obstacle.visible = false
	_shift = Vector2.ZERO
	if not await _wait(_logic.next_gap_ms() / 1000.0):
		return
	_obstacle_style.bg_color = get_theme_color("wrong", "Pad")
	_obstacle.visible = true
	_started_ms = Time.get_ticks_msec()
	_first_move_ms = -1
	_active = true


func _after_trial() -> void:
	if not await _wait(0.8):
		return
	if _logic.is_done():
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_next_trial()


func _reset_play_state() -> void:
	_active = false
	if _obstacle != null:
		_obstacle.visible = false
