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
