## Compensatory tracking: a dot keeps drifting away from the centre; move the
## mouse (or hold the arrow keys) to push it back and keep it centred.
extends TrialDrill

const DURATIONS: Array[int] = [20, 30, 45]
const DEFAULT_DURATION := 30
## Drift strength as a fraction of the stage half-size per second.
const DRIFT_SPEED := 0.45
const KEY_SPEED := 0.9
const MOUSE_GAIN := 0.0025

var _duration: int = DEFAULT_DURATION
var _duration_option: OptionButton
const ON_TARGET_RADIUS := 0.15

var _stats := TrackingStats.new()
var _on_target_samples: int = 0
var _stage: Control
var _cross: Label
var _dot: Panel
var _noise := FastNoiseLite.new()
var _offset := Vector2.ZERO
var _time := 0.0
var _playing: bool = false
var _ends_at_ms: int = 0
## False until the pointer has been parked once, so the first frame adds no jump.
var _pointer_parked: bool = false
## Warping the pointer is unavailable on web and mobile; there the frame-to-frame
## pointer delta is used instead.
var _can_warp: bool = not (OS.has_feature("web") or OS.has_feature("mobile"))
var _pointer_input := Vector2.ZERO
var _last_pointer := Vector2.ZERO


func _uses_trial_count() -> bool:
	return false


func _build_extras(parent: VBoxContainer) -> void:
	_duration_option = _add_option_row(parent, "TRACKING_DURATION", DURATIONS, _duration)


func _apply_extra_config(config: Dictionary) -> void:
	var requested: int = config.get("duration_s", DEFAULT_DURATION)
	if DURATIONS.has(requested):
		_duration = requested
	_duration_option.select(_duration_option.get_item_index(_duration))


func _collect_extra_config() -> Dictionary:
	return {"duration_s": _duration}


func _on_start_pressed() -> void:
	_duration = _duration_option.get_selected_id()
	super()


func _build_play_area(parent: Control) -> void:
	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(_stage)
	_cross = _make_stimulus_label(_stage, 64)
	_cross.text = "+"
	_cross.theme_type_variation = &"DimLabel"
	_dot = Panel.new()
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.size = Vector2(36, 36)
	var style := StyleBoxFlat.new()
	style.bg_color = get_theme_color("lit", "Board")
	style.set_corner_radius_all(18)
	_dot.add_theme_stylebox_override("panel", style)
	_stage.add_child(_dot)
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.35


func _input(event: InputEvent) -> void:
	if not _playing or _can_warp:
		return
	var relative := Vector2.ZERO
	var motion := event as InputEventMouseMotion
	var drag := event as InputEventScreenDrag
	if motion != null and motion.device != InputEvent.DEVICE_ID_EMULATION:
		relative = motion.relative
	elif drag != null:
		relative = drag.relative
	else:
		return
	var scale := get_viewport().get_final_transform().get_scale()
	_pointer_input += Vector2(relative.x / maxf(scale.x, 0.001), relative.y / maxf(scale.y, 0.001))


func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	# The pointer is parked at the stage centre every frame, so its displacement
	# since the last frame is the player's relative mouse movement.
	var centre := _stage.size * 0.5
	var pointer := _stage.get_local_mouse_position()
	if _can_warp:
		var pointer_delta := pointer - centre
		if _pointer_parked and pointer_delta.length_squared() > 0.0:
			_offset += pointer_delta * MOUSE_GAIN
		if pointer_delta.length_squared() > 0.0 or not _pointer_parked:
			Input.warp_mouse(_stage.get_screen_position() + centre)
			_pointer_parked = true
	else:
		# No warping (web): the motion events themselves steer, a real mouse or
		# a dragging finger; a tap on the screen moves nothing.
		_offset += _pointer_input * MOUSE_GAIN
		_pointer_input = Vector2.ZERO
	var drift := Vector2(_noise.get_noise_2d(_time, 0.0), _noise.get_noise_2d(0.0, _time + 100.0)) * DRIFT_SPEED
	_offset += drift * delta
	var keys := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_offset += keys * KEY_SPEED * delta
	_offset = _offset.clamp(Vector2(-1, -1), Vector2(1, 1))
	_stats.add(_offset.length())
	if _offset.length() <= ON_TARGET_RADIUS:
		_on_target_samples += 1
	var half := minf(_stage.size.x, _stage.size.y) * 0.5
	_dot.position = _stage.size * 0.5 + _offset * half - _dot.size * 0.5
	var remaining := maxi(0, _ends_at_ms - Time.get_ticks_msec())
	_set_progress_text(Format.seconds_short(remaining))
	if remaining <= 0:
		_finish()


func _run_trials() -> void:
	_stats = TrackingStats.new()
	_on_target_samples = 0
	_noise.seed = _rng.randi()
	_offset = Vector2.ZERO
	_time = 0.0
	_ends_at_ms = Time.get_ticks_msec() + _duration * 1000
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_pointer_parked = false
	_playing = true


func _reset_play_state() -> void:
	_playing = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_target_fraction() -> float:
	return float(_on_target_samples) / _stats.samples if _stats.samples > 0 else 0.0


func _finish() -> void:
	_playing = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var result := DrillResult.new()
	result.drill_id = definition.id
	result.config = get_config()
	result.total_ms = _duration * 1000
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["TRACKING_MEAN_DISTANCE", Format.percent(_stats.mean())]),
		PackedStringArray(["TRACKING_RMS", Format.percent(_stats.rms())]),
		PackedStringArray(["TRACKING_MAX", Format.percent(_stats.max_distance)]),
		PackedStringArray(["PURSUIT_ON_TARGET", Format.percent(_on_target_fraction())]),
	]
	result.details = {"mean": _stats.mean(), "rms": _stats.rms(), "max": _stats.max_distance}
	result.metrics = {"on_target": _on_target_fraction(), "mean_distance": _stats.mean()}
	_complete(result)
