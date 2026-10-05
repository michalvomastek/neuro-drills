## Go/No-Go: click or press space on a green disc, do nothing on a red one.
extends TrialDrill

const DISC_SIZE := 220.0

var _adaptive: bool = false
var _adaptive_check: CheckBox
var _auditory: bool = false
var _auditory_check: CheckBox
var _logic: GoNoGoLogic
var _pad: Button
var _disc: Panel
var _disc_style: StyleBoxFlat
var _stimulus_id: int = 0
var _stimulus_active: bool = false
var _stimulus_ms: int = 0


func _trial_options() -> Array[int]:
	return [20, 30, 50]


func _default_trials() -> int:
	return 30


func _build_extras(parent: VBoxContainer) -> void:
	_adaptive_check = CheckBox.new()
	_adaptive_check.text = tr("GONOGO_OPT_ADAPTIVE")
	parent.add_child(_adaptive_check)
	_auditory_check = CheckBox.new()
	_auditory_check.text = tr("GONOGO_OPT_AUDITORY")
	parent.add_child(_auditory_check)


func _apply_extra_config(config: Dictionary) -> void:
	_adaptive = config.get("adaptive", false)
	_adaptive_check.button_pressed = _adaptive
	_auditory = config.get("auditory", false)
	_auditory_check.button_pressed = _auditory


func _collect_extra_config() -> Dictionary:
	return {"adaptive": _adaptive, "auditory": _auditory}


func _on_start_pressed() -> void:
	_adaptive = _adaptive_check.button_pressed
	_auditory = _auditory_check.button_pressed
	super()


func _build_play_area(parent: Control) -> void:
	_pad = _make_pad()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.pressed.connect(_on_response)
	parent.add_child(_pad)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	_disc = Panel.new()
	_disc.custom_minimum_size = Vector2(DISC_SIZE, DISC_SIZE)
	_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disc_style = StyleBoxFlat.new()
	_disc_style.set_corner_radius_all(roundi(DISC_SIZE / 2.0))
	_disc.add_theme_stylebox_override("panel", _disc_style)
	_disc.visible = false
	center.add_child(_disc)


func _handle_response(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_response()
		get_viewport().set_input_as_handled()


func _reset_play_state() -> void:
	_stimulus_active = false
	if _disc != null:
		_disc.visible = false


func _run_trials() -> void:
	_logic = GoNoGoLogic.new(trials, _rng, _adaptive)
	_next_trial()


func _next_trial() -> void:
	_disc.visible = false
	_stimulus_active = false
	if not await _wait(_logic.next_gap_ms() / 1000.0):
		return
	_stimulus_id += 1
	var stimulus := _stimulus_id
	if _auditory:
		Sfx.play("high" if _logic.current_is_go() else "low")
	else:
		_disc_style.bg_color = get_theme_color("go" if _logic.current_is_go() else "wrong", "Pad")
		_disc.visible = true
	_stimulus_active = true
	_stimulus_ms = Time.get_ticks_msec()
	if not await _wait(_logic.stimulus_ms() / 1000.0):
		return
	if stimulus != _stimulus_id or not _stimulus_active:
		return
	_stimulus_active = false
	_logic.record_no_response()
	_advance()


func _on_response() -> void:
	if not _running or not _stimulus_active:
		return
	_stimulus_active = false
	var correct := _logic.record_response(Time.get_ticks_msec() - _stimulus_ms)
	if not correct:
		_flash_pad(_pad, get_theme_color("wrong_dim", "Pad"), 0.5)
	_advance()


func _advance() -> void:
	_disc.visible = false
	if _adaptive:
		_set_progress_text("%d ms   %d / %d" % [roundi(_logic.stimulus_ms()), _logic.current, trials])
	else:
		_set_progress(_logic.current)
	if _logic.is_done():
		_complete(_logic.build_result(definition.id, get_config()))
	else:
		_next_trial()
