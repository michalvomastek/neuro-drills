## Smooth pursuit: a target glides along a Lissajous path; keep the mouse
## pointer on it. Scores the mean distance between pointer and target.
extends TrialDrill

const DURATIONS: Array[int] = [20, 30, 45]
const DEFAULT_DURATION := 30
const SPEEDS: Array[int] = [1, 2, 3]
const DEFAULT_SPEED := 2
const TARGET_SIZE := 44.0

var _duration: int = DEFAULT_DURATION
var _speed: int = DEFAULT_SPEED
var _duration_option: OptionButton
var _speed_option: OptionButton
var _stats := TrackingStats.new()
var _stage: Control
var _target: Panel
var _target_style: StyleBoxFlat
var _time := 0.0
var _playing: bool = false
var _ends_at_ms: int = 0
var _phase := Vector2.ZERO
var _on_target_samples: int = 0
var _total_samples: int = 0


func _uses_trial_count() -> bool:
	return false


func _build_extras(parent: VBoxContainer) -> void:
	_duration_option = _add_option_row(parent, "TRACKING_DURATION", DURATIONS, _duration)
	_speed_option = _add_option_row(parent, "PURSUIT_SPEED", SPEEDS, _speed)


func _apply_extra_config(config: Dictionary) -> void:
	var requested: int = config.get("duration_s", DEFAULT_DURATION)
	if DURATIONS.has(requested):
		_duration = requested
	var speed: int = config.get("speed", DEFAULT_SPEED)
	if SPEEDS.has(speed):
		_speed = speed
	_duration_option.select(_duration_option.get_item_index(_duration))
	_speed_option.select(_speed_option.get_item_index(_speed))


func _collect_extra_config() -> Dictionary:
	return {"duration_s": _duration, "speed": _speed}


func _on_start_pressed() -> void:
	_duration = _duration_option.get_selected_id()
	_speed = _speed_option.get_selected_id()
	super()


func _build_play_area(parent: Control) -> void:
	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(_stage)
	_target = Panel.new()
	_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target.size = Vector2(TARGET_SIZE, TARGET_SIZE)
	_target_style = StyleBoxFlat.new()
	_target_style.bg_color = get_theme_color("lit", "Board")
	_target_style.set_corner_radius_all(roundi(TARGET_SIZE / 2.0))
	_target.add_theme_stylebox_override("panel", _target_style)
	_stage.add_child(_target)


func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta * (0.35 + 0.25 * _speed)
	var normalized := Vector2(sin(_time * 1.0 + _phase.x), sin(_time * 1.6 + _phase.y))
	var centre := _stage.size * 0.5
	var extent := Vector2(_stage.size.x * 0.42, _stage.size.y * 0.4)
	var target_centre := centre + normalized * extent
	_target.position = target_centre - _target.size * 0.5
	var pointer := _stage.get_local_mouse_position()
	var distance := pointer.distance_to(target_centre) / TARGET_SIZE
	_stats.add(distance)
	_total_samples += 1
	if distance <= 1.0:
		_on_target_samples += 1
	_target_style.bg_color = get_theme_color("correct" if distance <= 1.0 else "lit", "Pad" if distance <= 1.0 else "Board")
	var remaining := maxi(0, _ends_at_ms - Time.get_ticks_msec())
	_set_progress_text(Format.seconds_short(remaining))
	if remaining <= 0:
		_finish()


func _reset_play_state() -> void:
	_playing = false


func _run_trials() -> void:
	_stats = TrackingStats.new()
	_on_target_samples = 0
	_total_samples = 0
	_time = 0.0
	_phase = Vector2(_rng.randf_range(0.0, TAU), _rng.randf_range(0.0, TAU))
	_ends_at_ms = Time.get_ticks_msec() + _duration * 1000
	_playing = true


func _finish() -> void:
	_playing = false
	var result := DrillResult.new()
	result.drill_id = definition.id
	result.config = get_config()
	result.total_ms = _duration * 1000
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["PURSUIT_MEAN_DISTANCE", "%.2f" % _stats.mean()]),
		PackedStringArray(["PURSUIT_ON_TARGET", Format.percent(_on_target_fraction())]),
		PackedStringArray(["TRACKING_MAX", "%.1f" % _stats.max_distance]),
	]
	result.details = {"mean": _stats.mean(), "max": _stats.max_distance}
	_complete(result)


func _on_target_fraction() -> float:
	return float(_on_target_samples) / _total_samples if _total_samples > 0 else 0.0
