## Asymmetrical divided attention: the left hand keeps a drifting dot centred
## with the mouse while the right hand answers a Go/No-Go stream of discs
## with space. Both tasks are scored.
extends TrialDrill

const DRIFT_SPEED := 0.4
const MOUSE_GAIN := 0.0025
const DISC_SIZE := 120.0

var _tracking := TrackingStats.new()
var _gonogo: GoNoGoLogic
var _left: Control
var _right: Control
var _cross: Label
var _dot: Panel
var _disc: Panel
var _disc_style: StyleBoxFlat
var _noise := FastNoiseLite.new()
var _offset := Vector2.ZERO
var _time := 0.0
var _playing: bool = false
var _stimulus_active: bool = false
var _stimulus_ms: int = 0
var _last_pointer := Vector2.ZERO
var _pointer_ready: bool = false


func _trial_options() -> Array[int]:
	return [20, 30, 45]


func _default_trials() -> int:
	return 20


func _build_play_area(parent: Control) -> void:
	var halves := HBoxContainer.new()
	halves.set_anchors_preset(Control.PRESET_FULL_RECT)
	halves.add_theme_constant_override("separation", 16)
	parent.add_child(halves)
	_left = Panel.new()
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.mouse_filter = Control.MOUSE_FILTER_PASS
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = get_theme_color("occluder", "Board").darkened(0.3)
	left_style.set_corner_radius_all(8)
	_left.add_theme_stylebox_override("panel", left_style)
	halves.add_child(_left)
	_cross = _make_stimulus_label(_left, 56)
	_cross.text = "+"
	_cross.theme_type_variation = &"DimLabel"
	_dot = Panel.new()
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.size = Vector2(32, 32)
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = get_theme_color("lit", "Board")
	dot_style.set_corner_radius_all(16)
	_dot.add_theme_stylebox_override("panel", dot_style)
	_left.add_child(_dot)
	var right_pad := _make_pad()
	right_pad.pressed.connect(_on_response)
	halves.add_child(right_pad)
	_right = right_pad
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_pad.add_child(center)
	_disc = Panel.new()
	_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disc.custom_minimum_size = Vector2(DISC_SIZE, DISC_SIZE)
	_disc_style = StyleBoxFlat.new()
	_disc_style.set_corner_radius_all(roundi(DISC_SIZE / 2.0))
	_disc.add_theme_stylebox_override("panel", _disc_style)
	_disc.visible = false
	center.add_child(_disc)
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.35


func _handle_response(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_response()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	var drift := Vector2(_noise.get_noise_2d(_time, 0.0), _noise.get_noise_2d(0.0, _time + 50.0)) * DRIFT_SPEED
	_offset += drift * delta
	var pointer := get_local_mouse_position()
	if _pointer_ready:
		var pointer_delta := pointer - _last_pointer
		if pointer_delta.length() < 60.0:
			_offset += pointer_delta * MOUSE_GAIN
	_last_pointer = pointer
	_pointer_ready = true
	_offset = _offset.clamp(Vector2(-1, -1), Vector2(1, 1))
	_tracking.add(_offset.length())
	var half := minf(_left.size.x, _left.size.y) * 0.5 - 20.0
	_dot.position = _left.size * 0.5 + _offset * half - _dot.size * 0.5


func _run_trials() -> void:
	_tracking = TrackingStats.new()
	_gonogo = GoNoGoLogic.new(trials, _rng)
	_noise.seed = _rng.randi()
	_offset = Vector2.ZERO
	_time = 0.0
	_pointer_ready = false
	_playing = true
	_run_stream()


func _run_stream() -> void:
	for i in trials:
		if not await _wait(_gonogo.next_gap_ms() / 1000.0):
			return
		_disc_style.bg_color = get_theme_color("go" if _gonogo.current_is_go() else "wrong", "Pad")
		_disc.visible = true
		_stimulus_active = true
		_stimulus_ms = Time.get_ticks_msec()
		if not await _wait(_gonogo.stimulus_ms() / 1000.0):
			return
		if _stimulus_active:
			_stimulus_active = false
			_gonogo.record_no_response()
		_disc.visible = false
		_set_progress(_gonogo.current)
	_playing = false
	_complete(_build_result())


func _on_response() -> void:
	if not _running or not _stimulus_active:
		return
	_stimulus_active = false
	var correct := _gonogo.record_response(Time.get_ticks_msec() - _stimulus_ms)
	_disc.visible = false
	if not correct:
		_flash_pad(_right as Button, get_theme_color("wrong_dim", "Pad"), 0.4)


func _build_result() -> DrillResult:
	var result := _gonogo.build_result(definition.id, get_config())
	result.summary_rows.push_front(PackedStringArray(["TRACKING_MEAN_DISTANCE", Format.percent(_tracking.mean())]))
	result.details["tracking_mean"] = _tracking.mean()
	result.details["tracking_rms"] = _tracking.rms()
	return result


func _reset_play_state() -> void:
	_playing = false
	_stimulus_active = false
	if _disc != null:
		_disc.visible = false
