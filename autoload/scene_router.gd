## Swaps the single visible screen inside the host control that App attaches.
extends Node

const MAIN_MENU_SCENE_PATH := "res://ui/main_menu/main_menu.tscn"
const RESULTS_SCENE_PATH := "res://ui/results/results_screen.tscn"
const PROGRESS_SCENE_PATH := "res://ui/progress/progress_screen.tscn"
const FEEDBACK_SCENE_PATH := "res://ui/feedback/feedback_screen.tscn"

var _host: Control
var _current: Node


func attach(host: Control) -> void:
	_host = host


func show_menu() -> void:
	_swap(_instantiate(MAIN_MENU_SCENE_PATH))


func start_drill(id: StringName, config: Dictionary = {}, autostart: bool = false) -> void:
	var definition := DrillRegistry.find(id)
	if definition == null:
		push_error("SceneRouter: unknown drill %s" % id)
		show_menu()
		return
	var drill := _instantiate(definition.scene_path) as Drill
	if drill == null:
		push_error("SceneRouter: scene of %s does not extend Drill" % id)
		show_menu()
		return
	drill.finished.connect(show_results)
	drill.aborted.connect(show_menu)
	_swap(drill)
	drill.setup(definition, config, autostart)


func show_feedback() -> void:
	_swap(_instantiate(FEEDBACK_SCENE_PATH))


func show_progress() -> void:
	_swap(_instantiate(PROGRESS_SCENE_PATH))


func show_results(result: DrillResult) -> void:
	var screen := _instantiate(RESULTS_SCENE_PATH) as ResultsScreen
	_swap(screen)
	screen.setup(result)


func _instantiate(path: String) -> Node:
	var packed := load(path) as PackedScene
	assert(packed != null, "SceneRouter: cannot load %s" % path)
	return packed.instantiate()


func _swap(node: Node) -> void:
	assert(_host != null, "SceneRouter: attach() a host first")
	if _current != null:
		_current.queue_free()
	_current = node
	_host.add_child(node)
