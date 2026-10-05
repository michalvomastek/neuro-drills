## Base class of every drill scene. SceneRouter instantiates the scene, adds it
## to the tree and then calls [method setup]; the drill reports back through the
## signals and never navigates on its own.
class_name Drill
extends Control

## Emitted once with the run's result; the router then shows the results screen.
signal finished(result: DrillResult)
## Emitted when the player leaves the drill without finishing a run.
signal aborted

var definition: DrillDefinition


## [param config] is the drill's own configuration (may be empty for defaults).
## [param autostart] skips the setup panel and starts a run right away.
func setup(p_definition: DrillDefinition, config: Dictionary, autostart: bool) -> void:
	definition = p_definition
	if not is_node_ready():
		await ready
	_on_setup(config, autostart)


## Override in the drill scene. Called after the node is ready.
func _on_setup(_config: Dictionary, _autostart: bool) -> void:
	pass


## Makes [param button] fire once per touch tap while reacting on press.
## Godot hands a button both the touch event and the mouse event emulated
## from it; in ACTION_MODE_BUTTON_PRESS BaseButton acts on each, so one tap
## counted as two presses (seen on mobile: a correct Schulte cell also logged
## an error). Swallowing the touch leaves the emulated mouse event, which
## behaves exactly like a mouse click. Without mouse emulation the touch is
## the only event and is left alone.
static func make_press_button(button: BaseButton) -> void:
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	var emulated: bool = ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)
	if not emulated:
		return
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			button.accept_event())


## A short grow-and-settle on a correct answer (the control scales around its centre).
static func pop(control: Control, amount: float = 0.06, seconds: float = 0.18) -> void:
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE * (1.0 + amount), seconds * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, seconds * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A quick sideways shake on a wrong answer; ends exactly where it started.
static func shake(control: Control, distance: float = 6.0, seconds: float = 0.24) -> void:
	var origin := control.position
	var tween := control.create_tween()
	for i in 3:
		var sign := 1.0 if i % 2 == 0 else -1.0
		tween.tween_property(control, "position", origin + Vector2(distance * sign, 0), seconds / 6.0)
		tween.tween_property(control, "position", origin, seconds / 6.0)


## On the web, asks the browser to confirm before the page is closed or
## reloaded while a run is in progress (a tap on the wrong browser control
## otherwise throws the run away). No-op elsewhere.
static func set_leave_guard(active: bool) -> void:
	if not OS.has_feature("web"):
		return
	if active:
		JavaScriptBridge.eval("window.onbeforeunload = function (e) { e.preventDefault(); e.returnValue = ''; return ''; };")
	else:
		JavaScriptBridge.eval("window.onbeforeunload = null;")


## iOS Safari only delivers device motion after the page asked for it inside a
## user gesture; call this from the Start button of a drill that uses tilt.
static func request_motion_permission() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("if (window.DeviceMotionEvent && typeof DeviceMotionEvent.requestPermission === 'function') { DeviceMotionEvent.requestPermission().catch(function () {}); }")
