## Coincidence anticipation: watch the disc, it hides behind the wall; press
## space or click exactly when it would cross the line.
extends TrialDrill

const FEEDBACK_SECONDS := 1.2

var _logic: AnticipationLogic
var _stage: Control
var _disc: Panel
var _occluder: ColorRect
var _line: ColorRect
var _feedback: Label
var _pad: Button
var _started_ms: int = 0
var _playing: bool = false


func _trial_options() -> Array[int]:
	return [8, 12, 16]


func _default_trials() -> int:
	return 8


func _build_play_area(parent: Control) -> void:
	_pad = _make_pad()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.pressed.connect(_on_press)
	parent.add_child(_pad)
	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_stage)
	_disc = Panel.new()
	_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = get_theme_color("lit", "Board")
	style.set_corner_radius_all(40)
	_disc.add_theme_stylebox_override("panel", style)
	_disc.visible = false
	_stage.add_child(_disc)
	_occluder = ColorRect.new()
	_occluder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_occluder.color = get_theme_color("occluder", "Board")
	_stage.add_child(_occluder)
	_line = ColorRect.new()
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.color = get_theme_color("wrong", "Pad")
	_stage.add_child(_line)
	_feedback = _make_stimulus_label(parent, 48)
	_stage.resized.connect(_layout)


func _layout() -> void:
	var w := _stage.size.x
	var h := _stage.size.y
	_occluder.position = Vector2(w * AnticipationLogic.OCCLUDER_X, 0)
	_occluder.size = Vector2(w * (1.0 - AnticipationLogic.OCCLUDER_X), h)
	_line.position = Vector2(w * AnticipationLogic.TARGET_X - 2, 0)
	_line.size = Vector2(4, h)
	_disc.size = Vector2(h * 0.08, h * 0.08)


func _handle_response(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_press()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _playing:
		return
	var elapsed := Time.get_ticks_msec() - _started_ms
	var x := _logic.position_at(elapsed)
	_disc.position = Vector2(_stage.size.x * x - _disc.size.x * 0.5, (_stage.size.y - _disc.size.y) * 0.5)
	_disc.visible = x < AnticipationLogic.OCCLUDER_X
	if elapsed > _logic.ideal_time_ms() + AnticipationLogic.RESPONSE_LIMIT_MS:
		_on_press()


func _reset_play_state() -> void:
	_playing = false
	if _disc != null:
		_disc.visible = false


func _run_trials() -> void:
	_logic = AnticipationLogic.new(trials, _rng)
	_layout()
	_next_trial()


func _next_trial() -> void:
	_playing = false
	_feedback.text = ""
	_disc.visible = false
	if not await _wait(1.0):
		return
	_started_ms = Time.get_ticks_msec()
	_playing = true


func _on_press() -> void:
	if not _running or not _playing:
		return
	_playing = false
	var error := _logic.record_press(Time.get_ticks_msec() - _started_ms)
	_disc.visible = false
	var direction := tr("ANTICIPATION_EARLY") if error < 0 else tr("ANTICIPATION_LATE")
	_feedback.text = "%+d ms  %s" % [error, direction]
	_feedback.add_theme_color_override("font_color", get_theme_color("correct" if absi(error) <= 50 else "wrong", "Pad"))
	_set_progress(_logic.current)
	if not await _wait(FEEDBACK_SECONDS):
		return
	if _logic.is_done():
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_next_trial()
