## Smoke test of every registered drill: starts each one with the countdown
## on, waits until it should be running, checks the running flag and the play
## panel, then returns to the menu. Started by `tools/godot.sh smoke` under a
## (virtual) display, because the drills render and use the pointer.
extends SceneTree

const SETTLE_SECONDS := 5.5

var _host: Control
var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	Layout.apply_scale(root)
	# The window still reports its default size here; the real one arrives a frame later.
	root.size_changed.connect(func() -> void: Layout.apply_scale(root))
	_host = Control.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_host)
	var router: Node = root.get_node("SceneRouter")
	router.call("attach", _host)
	_run_all(router)


func _run_all(router: Node) -> void:
	var registry: Node = root.get_node("DrillRegistry")
	var definitions: Array = registry.call("get_all")
	for definition: DrillDefinition in definitions:
		router.call("start_drill", definition.id, {"countdown": true}, true)
		await create_timer(SETTLE_SECONDS).timeout
		var drill: Node = _host.get_child(0) if _host.get_child_count() > 0 else null
		var running_flag: bool = drill.get("_running") if drill != null else false
		var running := drill != null and running_flag
		var play_panel: Control = drill.get("_play_panel") if drill != null else null
		var visible := play_panel != null and play_panel.visible
		if running and visible:
			print("ok   %s" % definition.id)
		else:
			_failures.append(String(definition.id))
			print("FAIL %s (running=%s, play panel visible=%s)" % [definition.id, running, visible])
		router.call("show_menu")
		await create_timer(0.2).timeout
	print("%d drill(s) started, %d failed" % [definitions.size(), _failures.size()])
	quit(1 if not _failures.is_empty() else 0)
