## Simple reaction time: the pad turns green after a random wait, click or
## press space as fast as possible.
extends TrialDrill

enum State { IDLE, WAITING, GO, FEEDBACK }

const FEEDBACK_SECONDS := 0.8

var _logic: ReactionLogic
var _pad: Button
var _state := State.IDLE
var _trial_id: int = 0
var _stimulus_ms: int = 0


func _trial_options() -> Array[int]:
	return [3, 5, 10]


func _default_trials() -> int:
	return 5


func _build_play_area(parent: Control) -> void:
	_pad = _make_pad("", 56)
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.pressed.connect(_on_pad_pressed)
	parent.add_child(_pad)


func _handle_response(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_pad_pressed()
		get_viewport().set_input_as_handled()


func _run_trials() -> void:
	_logic = ReactionLogic.new(trials, _rng)
	_start_trial()


func _start_trial() -> void:
	_trial_id += 1
	var trial := _trial_id
	_state = State.WAITING
	_pad.text = tr("REACTION_WAIT")
	_clear_pad_flash(_pad)
	if not await _wait(_logic.next_delay_ms() / 1000.0):
		return
	if trial != _trial_id or _state != State.WAITING:
		return
	_state = State.GO
	_stimulus_ms = Time.get_ticks_msec()
	_pad.text = tr("REACTION_GO")
	_set_pad_color(_pad, get_theme_color("go", "Pad"))


func _on_pad_pressed() -> void:
	if not _running:
		return
	match _state:
		State.WAITING:
			_logic.record_premature()
			_state = State.FEEDBACK
			_pad.text = tr("REACTION_EARLY")
			_flash_pad(_pad, get_theme_color("wrong", "Pad"), FEEDBACK_SECONDS)
			if await _wait(FEEDBACK_SECONDS):
				_start_trial()
		State.GO:
			var rt := Time.get_ticks_msec() - _stimulus_ms
			_logic.record_reaction(rt)
			_state = State.FEEDBACK
			_pad.text = tr("REACTION_MS") % rt
			_clear_pad_flash(_pad)
			_set_progress(_logic.stats.count())
			if not await _wait(FEEDBACK_SECONDS):
				return
			if _logic.is_done():
				_complete(_logic.build_result(definition.id, get_config()))
			else:
				_start_trial()
