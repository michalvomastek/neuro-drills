## Dynamic visual acuity: a ring with a gap flies past; say where the gap was
## with the arrow keys or the four buttons.
extends TrialDrill

const RING_SIZE := 70.0
const ARROWS: Array[String] = ["▲", "▶", "▼", "◀"]

var _logic: AcuityLogic
var _stage: Control
var _ring: LandoltRing
var _buttons: Array[Button] = []
var _row: HBoxContainer
var _flying: bool = false
var _flight_time := 0.0
var _accepting: bool = false


func _trial_options() -> Array[int]:
	return [15, 25, 40]


func _default_trials() -> int:
	return 15


func _build_play_area(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	parent.add_child(vbox)
	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.clip_contents = true
	vbox.add_child(_stage)
	_ring = LandoltRing.new()
	_ring.size = Vector2(RING_SIZE, RING_SIZE)
	_ring.visible = false
	_stage.add_child(_ring)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 12)
	_row.custom_minimum_size = Vector2(0, 100)
	vbox.add_child(_row)
	for i in ARROWS.size():
		var button := _make_pad(ARROWS[i], 40)
		button.pressed.connect(_on_answer.bind(i))
		_row.add_child(button)
		_buttons.append(button)


func _handle_response(event: InputEvent) -> void:
	var actions: Array[StringName] = [&"ui_up", &"ui_right", &"ui_down", &"ui_left"]
	for i in actions.size():
		if event.is_action_pressed(actions[i]):
			_on_answer(i)
			get_viewport().set_input_as_handled()
			return


func _process(delta: float) -> void:
	if not _flying:
		return
	_flight_time += delta
	var progress := _flight_time / _logic.flight_seconds()
	var x := -0.1 + progress * 1.2
	if _logic.direction < 0:
		x = 1.1 - progress * 1.2
	_ring.position = Vector2(_stage.size.x * x - RING_SIZE * 0.5, (_stage.size.y - RING_SIZE) * 0.5)
	if progress >= 1.0:
		_flying = false
		_ring.visible = false
		_accepting = true


func _reset_play_state() -> void:
	_flying = false
	_accepting = false
	if _ring != null:
		_ring.visible = false


func _run_trials() -> void:
	_logic = AcuityLogic.new(trials, _rng)
	_next_trial()


func _next_trial() -> void:
	_accepting = false
	_set_progress_text("%.2f   %d / %d" % [_logic.speed(), _logic.current, trials])
	if not await _wait(0.8):
		return
	_logic.new_trial()
	_ring.gap = _logic.gap
	_ring.queue_redraw()
	_flight_time = 0.0
	_ring.visible = true
	_flying = true


func _on_answer(index: int) -> void:
	if not _running or not _accepting:
		return
	_accepting = false
	var correct := _logic.answer(index as AcuityLogic.Gap)
	_flash_pad(_buttons[index], get_theme_color("correct" if correct else "wrong", "Pad"), 0.4)
	if not await _wait(0.4):
		return
	if _logic.is_done():
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_next_trial()
