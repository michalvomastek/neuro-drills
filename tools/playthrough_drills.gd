## Plays every registered drill to the end with random input and checks the
## result: the drill must emit `finished` within a time limit, the result must
## carry metrics and summary rows, and the history record and the benchmark
## must build from it. Started by `tools/godot.sh playthrough` under a
## (virtual) display. Time runs fast (Engine.time_scale) so waits are short;
## clocks based on Time.get_ticks_msec are unaffected, which is why the real
## time limit per drill is generous.
extends SceneTree

const TIME_SCALE := 6.0
const LIMIT_SECONDS := 150.0
const TICK_SECONDS := 0.1
## With few buttons (reaction pads) a press happens only now and then, so a
## waiting period can pass without a premature press; with many buttons
## (cells, keypads) several are pressed per tick.
const FEW_BUTTONS := 4
const PRESS_CHANCE := 0.25
const MAX_PRESSES_PER_TICK := 10

var _host: Control
var _router: Node
var _failures: PackedStringArray = PackedStringArray()
var _result: DrillResult
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 12345
	Layout.apply_scale(root)
	_host = Control.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_host)
	_router = root.get_node("SceneRouter")
	_router.call("attach", _host)
	Engine.time_scale = TIME_SCALE
	_run_all()


func _run_all() -> void:
	var registry: Node = root.get_node("DrillRegistry")
	var definitions: Array = registry.call("get_all")
	var only := OS.get_environment("PLAYTHROUGH_ONLY")
	for definition: DrillDefinition in definitions:
		if not only.is_empty() and not only.split(",").has(String(definition.id)):
			continue
		await _play(definition)
	print("%d drill(s) played, %d failed" % [definitions.size() if only.is_empty() else only.split(",").size(), _failures.size()])
	quit(1 if not _failures.is_empty() else 0)


func _play(definition: DrillDefinition) -> void:
	_result = null
	var started := Time.get_ticks_msec()
	_router.call("start_drill", definition.id, {"countdown": false}, true)
	await process_frame
	await process_frame
	var drill: Node = null
	for child in _host.get_children():
		if child.has_signal("finished") and not child.is_queued_for_deletion():
			drill = child
	if drill == null:
		_fail(definition, "drill scene did not load")
		return
	drill.connect("finished", _on_finished)
	var back_text := TranslationServer.translate("COMMON_BACK")
	while _result == null and (Time.get_ticks_msec() - started) / 1000.0 < LIMIT_SECONDS:
		await create_timer(TICK_SECONDS * TIME_SCALE).timeout
		if not is_instance_valid(drill) or drill.get_parent() == null:
			break
		_poke(drill, back_text)
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	if _result == null:
		_fail(definition, "did not finish within %.0f s" % LIMIT_SECONDS)
	else:
		var problems := _check(_result)
		if problems.is_empty():
			print("ok   %-24s %5.1f s  %s" % [definition.id, seconds, _result.metrics])
		else:
			_fail(definition, "; ".join(problems))
	_router.call("show_menu")
	await create_timer(0.2 * TIME_SCALE).timeout


## Random input: presses visible buttons (never Back), the accept action and
## a click somewhere in the window, so pads, keypads, cells and drawn boards
## all receive something.
func _poke(drill: Node, back_text: String) -> void:
	var buttons: Array[Button] = []
	_collect_buttons(drill, buttons, back_text)
	var presses := 0
	if buttons.size() > FEW_BUTTONS:
		presses = clampi(buttons.size() / 3, 1, MAX_PRESSES_PER_TICK)
	elif not buttons.is_empty() and _rng.randf() < PRESS_CHANCE:
		presses = 1
	for i in presses:
		var button := buttons[_rng.randi_range(0, buttons.size() - 1)]
		if is_instance_valid(button) and not button.disabled:
			button.pressed.emit()
	if buttons.size() > FEW_BUTTONS or _rng.randf() < PRESS_CHANCE:
		_press_accept()
	if buttons.size() > FEW_BUTTONS or _rng.randf() < PRESS_CHANCE:
		_click_somewhere()
	if OS.get_environment("PLAYTHROUGH_DEBUG") == "1" and _rng.randf() < 0.05:
		var running: Variant = drill.get("_running")
		var names := PackedStringArray()
		for b: Button in buttons.slice(0, 6):
			names.append("%s[%s]" % [b.name, b.text])
		var logic: Object = drill.get("_logic")
		var progress: Variant = logic.get("next_index") if logic != null else null
		print("  debug: %d buttons, presses %d, running %s, next_index %s, %s" % [buttons.size(), presses, running, progress, ", ".join(names)])


func _press_accept() -> void:
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	Input.parse_input_event(accept)
	var release := InputEventAction.new()
	release.action = &"ui_accept"
	release.pressed = false
	Input.parse_input_event(release)


func _click_somewhere() -> void:
	var size := root.get_visible_rect().size
	var at := Vector2(_rng.randf_range(0.1, 0.9) * size.x, _rng.randf_range(0.15, 0.9) * size.y)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	Input.parse_input_event(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at
	up.global_position = at
	Input.parse_input_event(up)


func _collect_buttons(node: Node, out: Array[Button], back_text: String) -> void:
	var button := node as Button
	# A scene button keeps its translation key as text, a code-built one the translation.
	if button != null and button.is_visible_in_tree() and button.text != back_text and button.text != "COMMON_BACK":
		out.append(button)
	for child in node.get_children():
		_collect_buttons(child, out, back_text)


func _on_finished(result: DrillResult) -> void:
	_result = result


func _check(result: DrillResult) -> PackedStringArray:
	var problems := PackedStringArray()
	if result.metrics.is_empty():
		problems.append("no metrics")
	if result.summary_rows.is_empty():
		problems.append("no summary rows")
	if result.finished_at_unix <= 0:
		problems.append("no finished_at_unix")
	var primary := MetricCatalog.primary_of(result.drill_id)
	if primary.is_empty():
		problems.append("no primary metric")
	elif not result.metrics.has(primary["metric"]):
		problems.append("primary metric %s missing" % primary["metric"])
	var record := StatsHistory.make_record(result)
	if record.is_empty():
		problems.append("no history record")
	var verdict := Benchmarks.evaluate(result)
	if not verdict.is_empty() and not verdict.has("level"):
		problems.append("benchmark without level")
	return problems


func _fail(definition: DrillDefinition, why: String) -> void:
	_failures.append(String(definition.id))
	print("FAIL %s: %s" % [definition.id, why])
