## Swaps the single visible screen inside the host control that App attaches.
extends Node

const MAIN_MENU_SCENE_PATH := "res://ui/main_menu/main_menu.tscn"
const RESULTS_SCENE_PATH := "res://ui/results/results_screen.tscn"
const PROGRESS_SCENE_PATH := "res://ui/progress/progress_screen.tscn"
const FEEDBACK_SCENE_PATH := "res://ui/feedback/feedback_screen.tscn"
const TRAINING_SCENE_PATH := "res://ui/training/training_screen.tscn"
const SETTINGS_SCENE_PATH := "res://ui/settings/settings_screen.tscn"
const PROFILE_SCENE_PATH := "res://ui/profile/profile_screen.tscn"
const ONBOARDING_SCENE_PATH := "res://ui/onboarding/onboarding_screen.tscn"
const TRAINING_BRIEF_SCENE_PATH := "res://ui/training/training_brief.tscn"
const TRAINING_SUMMARY_SCENE_PATH := "res://ui/training/training_summary.tscn"

## Emitted after every swap with the screen's id (menu, training, progress,
## profile, settings, feedback), with DRILL_SETUP while a drill shows its
## setup panel, or with an empty name for a screen without the app bars (a
## running drill, results, brief, summary, onboarding).
signal screen_changed(screen: StringName)

## Screen id of a drill's setup panel: the bars stay, the title is the
## drill's name and the back arrow leaves the drill.
const DRILL_SETUP := &"drill_setup"

## The training in progress, or null when drills are played one by one.
var training: TrainingSession
## The drill on screen (setup panel, countdown or run), or null.
var current_drill: Drill

var _host: Control
var _current: Node


func attach(host: Control) -> void:
	_host = host


func show_menu() -> void:
	_swap(_instantiate(MAIN_MENU_SCENE_PATH), &"menu")


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
	drill.phase_changed.connect(_on_drill_phase_changed)
	_swap(drill)
	drill.setup(definition, config, autostart)


func _on_drill_phase_changed(in_setup: bool) -> void:
	screen_changed.emit(DRILL_SETUP if in_setup else &"")


## The back arrow of the app bar on a setup panel: leaves the drill the way
## its own Back button did (to the training screen when a training ran).
func abort_drill() -> void:
	if current_drill != null:
		_on_drill_aborted()


func _on_drill_aborted() -> void:
	if training != null:
		training = null
		show_training()
	else:
		show_menu()


func show_training() -> void:
	_swap(_instantiate(TRAINING_SCENE_PATH), &"training")


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


## Each step opens with a short brief (which drill, how to play, what it
## measures) so the player knows what comes after the countdown.
func _start_training_step() -> void:
	var screen := _instantiate(TRAINING_BRIEF_SCENE_PATH) as TrainingBrief
	_swap(screen)
	screen.setup(training)


## Called by the brief's Start button.
func start_training_step_now() -> void:
	if training == null:
		show_menu()
		return
	var step := training.current_step()
	var drill_id: String = step["drill_id"]
	var config: Dictionary = step["config"]
	start_drill(StringName(drill_id), config, true)


func show_feedback() -> void:
	_swap(_instantiate(FEEDBACK_SCENE_PATH), &"feedback")


func show_profile() -> void:
	_swap(_instantiate(PROFILE_SCENE_PATH), &"profile")


func show_onboarding() -> void:
	_swap(_instantiate(ONBOARDING_SCENE_PATH))


## Composes a training of [param minutes] from the weakest categories and starts it.
func start_suggested_training(minutes: int) -> void:
	var definitions := DrillRegistry.get_all()
	var now := int(Time.get_unix_time_from_system())
	var order := TrainingPlan.weak_categories(definitions, StatsStore.history, DrillRegistry.CATEGORY_ORDER, now)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var steps := TrainingPlan.suggest(definitions, minutes, order, rng, TrainingPlan.harder_configs(StatsStore.history))
	if steps.is_empty():
		show_menu()
		return
	start_training(TrainingSession.new(steps, ""))


func show_settings() -> void:
	_swap(_instantiate(SETTINGS_SCENE_PATH), &"settings")


func show_progress() -> void:
	_swap(_instantiate(PROGRESS_SCENE_PATH), &"progress")


func show_results(result: DrillResult) -> void:
	var screen := _instantiate(RESULTS_SCENE_PATH) as ResultsScreen
	_swap(screen)
	screen.setup(result)


func _instantiate(path: String) -> Node:
	var packed := load(path) as PackedScene
	assert(packed != null, "SceneRouter: cannot load %s" % path)
	return packed.instantiate()


func _swap(node: Node, screen: StringName = &"") -> void:
	assert(_host != null, "SceneRouter: attach() a host first")
	if _current != null:
		_current.queue_free()
	_current = node
	current_drill = node as Drill
	_host.add_child(node)
	screen_changed.emit(screen)
