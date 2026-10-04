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
