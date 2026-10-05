## Swaps the single visible screen inside the host control that App attaches.
extends Node

const MAIN_MENU_SCENE_PATH := "res://ui/main_menu/main_menu.tscn"
const RESULTS_SCENE_PATH := "res://ui/results/results_screen.tscn"
const PROGRESS_SCENE_PATH := "res://ui/progress/progress_screen.tscn"
const FEEDBACK_SCENE_PATH := "res://ui/feedback/feedback_screen.tscn"
const TRAINING_SCENE_PATH := "res://ui/training/training_screen.tscn"
const SETTINGS_SCENE_PATH := "res://ui/settings/settings_screen.tscn"
const TRAINING_SUMMARY_SCENE_PATH := "res://ui/training/training_summary.tscn"

## The training in progress, or null when drills are played one by one.
var training: TrainingSession

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
		# A saved plan may name a drill that no longer exists; the training cannot go on.
		training = null
		show_menu()
		return
	var drill := _instantiate(definition.scene_path) as Drill
	if drill == null:
		push_error("SceneRouter: scene of %s does not extend Drill" % id)
		training = null
		show_menu()
		return
	drill.finished.connect(show_results)
	drill.finished.connect(func(_result: DrillResult) -> void: Sfx.play("done"))
	drill.aborted.connect(_on_drill_aborted)
	_swap(drill)
	drill.setup(definition, config, autostart)


func _on_drill_aborted() -> void:
	if training != null:
		training = null
		show_training()
	else:
		show_menu()


func show_training() -> void:
	_swap(_instantiate(TRAINING_SCENE_PATH))


## Starts the first step of [param session]; the results screen moves on
## through [method continue_training].
func start_training(session: TrainingSession) -> void:
	training = session
	_start_training_step()


func continue_training() -> void:
	if training == null:
		show_menu()
		return
	if training.has_next():
		training.advance()
		_start_training_step()
	else:
		show_training_summary()


func abort_training() -> void:
	training = null


func show_training_summary() -> void:
	var screen := _instantiate(TRAINING_SUMMARY_SCENE_PATH) as TrainingSummary
	_swap(screen)
	screen.setup(training)
	training = null


func _start_training_step() -> void:
	var step := training.current_step()
	var drill_id: String = step["drill_id"]
	var config: Dictionary = step["config"]
	start_drill(StringName(drill_id), config, true)


func show_feedback() -> void:
	_swap(_instantiate(FEEDBACK_SCENE_PATH))


func show_settings() -> void:
	_swap(_instantiate(SETTINGS_SCENE_PATH))


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
