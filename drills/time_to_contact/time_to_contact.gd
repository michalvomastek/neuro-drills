## Time to contact in 3D: a ball flies at you and disappears halfway. Click
## where and when it would hit the screen.
extends TrialDrill

const FEEDBACK_SECONDS := 1.4

var _logic: TtcLogic
var _scene: Scene3D
var _ball: MeshInstance3D
var _pad: Button
var _marker: Panel
var _impact_marker: Panel
var _feedback: Label
var _started_ms: int = 0
var _playing: bool = false


func _trial_options() -> Array[int]:
	return [6, 10, 15]


func _default_trials() -> int:
	return 6


func _build_play_area(parent: Control) -> void:
	_scene = Scene3D.new(parent)
	_scene.camera.position = Vector3(0, 0, 0)
	_ball = Scene3D.make_sphere(0.35, Color(0.95, 0.55, 0.2))
	_ball.visible = false
	_scene.world.add_child(_ball)
	var floor_mesh := Scene3D.make_box(Vector3(14, 0.1, 30), Color(0.14, 0.16, 0.2))
	floor_mesh.position = Vector3(0, -2.5, -15)
	_scene.world.add_child(floor_mesh)
	for i in 6:
		var post := Scene3D.make_box(Vector3(0.15, 2.0, 0.15), Color(0.25, 0.28, 0.35))
		post.position = Vector3(-5.0 if i % 2 == 0 else 5.0, -1.5, -4.0 * (i / 2 + 1))
		_scene.world.add_child(post)
	_pad = _make_pad()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.flat = true
	_pad.self_modulate = Color(1, 1, 1, 0)
	_pad.pressed.connect(_on_press)
	parent.add_child(_pad)
	_marker = _make_marker(get_theme_color("lit", "Board"))
	_impact_marker = _make_marker(get_theme_color("correct", "Pad"))
	parent.add_child(_marker)
	parent.add_child(_impact_marker)
	_feedback = _make_stimulus_label(parent, 40)
	_feedback.vertical_alignment = VERTICAL_ALIGNMENT_TOP


func _make_marker(color: Color) -> Panel:
	var marker := Panel.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.size = Vector2(28, 28)
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.set_border_width_all(3)
	style.border_color = color
	style.set_corner_radius_all(14)
	marker.add_theme_stylebox_override("panel", style)
	marker.visible = false
	return marker


func _handle_response(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_press()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _playing:
		return
	var seconds := (Time.get_ticks_msec() - _started_ms) / 1000.0
	_ball.position = _logic.position_at(seconds)
	_ball.visible = _logic.is_visible_at(seconds)
	if seconds > _logic.flight_seconds() + TtcLogic.RESPONSE_LIMIT_MS / 1000.0:
		_on_press()


func _run_trials() -> void:
	_logic = TtcLogic.new(trials, _rng)
	_next_trial()


func _next_trial() -> void:
	_playing = false
	_ball.visible = false
	_marker.visible = false
	_impact_marker.visible = false
	_feedback.text = ""
	if not await _wait(1.0):
		return
	_started_ms = Time.get_ticks_msec()
	_playing = true


## Screen position of a world point, in the play area's coordinates.
func _project(point: Vector3) -> Vector2:
	var in_viewport := _scene.camera.unproject_position(point)
	var scale := _scene.container.size / Vector2(_scene.viewport.size)
	return in_viewport * scale


func _on_press() -> void:
	if not _running or not _playing:
		return
	_playing = false
	var seconds := (Time.get_ticks_msec() - _started_ms) / 1000.0
	var click := _pad.get_local_mouse_position()
	# Read the impact point before record() advances to the next trial.
	var impact_world := _logic.impact_point()
	var impact := _project(impact_world)
	var height := maxf(1.0, _pad.size.y)
	var error := _logic.record(seconds, click.distance_to(impact) / height)
	_marker.position = click - _marker.size * 0.5
	_marker.visible = true
	_impact_marker.position = impact - _impact_marker.size * 0.5
	_impact_marker.visible = true
	_ball.position = impact_world
	_ball.visible = true
	var direction := tr("ANTICIPATION_EARLY") if error < 0 else tr("ANTICIPATION_LATE")
	_feedback.text = "%+d ms  %s" % [error, direction]
	_set_progress(_logic.current)
	if not await _wait(FEEDBACK_SECONDS):
		return
	if _logic.is_done():
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_next_trial()


func _reset_play_state() -> void:
	_playing = false
	if _ball != null:
		_ball.visible = false
