## Rhythmic tapping: tap space or click with the pulsing disc; when it stops
## pulsing, keep the same tempo from memory.
extends TrialDrill

const TEMPOS: Array[int] = [60, 90, 120]
const DEFAULT_BPM := 90
const PULSE_SECONDS := 0.12

var _bpm: int = DEFAULT_BPM
var _bpm_option: OptionButton
var _logic: RhythmLogic
var _pad: Button
var _disc: Panel
var _disc_style: StyleBoxFlat
var _hint: Label
var _started_ms: int = 0
var _beats_shown: int = 0
var _cueing: bool = false
var _accepting: bool = false


func _uses_trial_count() -> bool:
	return false


func _build_extras(parent: VBoxContainer) -> void:
	_bpm_option = _add_option_row(parent, "RHYTHM_TEMPO", TEMPOS, _bpm)


func _apply_extra_config(config: Dictionary) -> void:
	var requested: int = config.get("bpm", DEFAULT_BPM)
	if TEMPOS.has(requested):
		_bpm = requested
	_bpm_option.select(_bpm_option.get_item_index(_bpm))


func _collect_extra_config() -> Dictionary:
	return {"bpm": _bpm}


func _on_start_pressed() -> void:
	_bpm = _bpm_option.get_selected_id()
	super()


func _build_play_area(parent: Control) -> void:
	_pad = _make_pad()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.pressed.connect(_on_tap)
	parent.add_child(_pad)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)
	_disc = Panel.new()
	_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disc.custom_minimum_size = Vector2(160, 160)
	_disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_disc_style = StyleBoxFlat.new()
	_disc_style.set_corner_radius_all(80)
	_disc_style.bg_color = get_theme_color("cell", "Board")
	_disc.add_theme_stylebox_override("panel", _disc_style)
	column.add_child(_disc)
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.theme_type_variation = &"DimLabel"
	_hint.add_theme_font_size_override("font_size", 28)
	column.add_child(_hint)


func _handle_response(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_tap()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _cueing:
		return
	var elapsed := Time.get_ticks_msec() - _started_ms
	var beat := int(elapsed / _logic.period_ms())
	if beat >= RhythmLogic.CUED_BEATS:
		_cueing = false
		_hint.text = tr("RHYTHM_CONTINUE")
		return
	var phase := fmod(elapsed, _logic.period_ms()) / 1000.0
	_disc_style.bg_color = get_theme_color("lit", "Board") if phase < PULSE_SECONDS else get_theme_color("cell", "Board")


func _reset_play_state() -> void:
	_cueing = false
	_accepting = false
	if _disc_style != null:
		_disc_style.bg_color = get_theme_color("cell", "Board")


func _run_trials() -> void:
	_logic = RhythmLogic.new(_bpm)
	_hint.text = tr("RHYTHM_TAP_ALONG")
	_set_progress_text("%d BPM   0 / %d" % [_bpm, _logic.total_taps()])
	if not await _wait(1.0):
		return
	_started_ms = Time.get_ticks_msec()
	_cueing = true
	_accepting = true


func _on_tap() -> void:
	if not _running or not _accepting:
		return
	_logic.record_tap(Time.get_ticks_msec())
	_flash_pad(_pad, get_theme_color("selected", "Board"), 0.15)
	_set_progress_text("%d BPM   %d / %d" % [_bpm, _logic.taps_ms.size(), _logic.total_taps()])
	if _logic.is_done():
		_accepting = false
		_cueing = false
		_complete(_logic.build_result(definition.id, get_config()))
