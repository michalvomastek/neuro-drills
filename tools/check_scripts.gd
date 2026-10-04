## Loads every GDScript of the project inside a running SceneTree so parse,
## analyzer and compile errors surface, including warnings configured as
## errors and references to autoload singletons. Started by `tools/godot.sh
## check`; user args may name specific res:// scripts.
extends SceneTree

const SKIPPED_DIRS: PackedStringArray = [".godot", ".git", "addons"]


func _initialize() -> void:
	var paths := PackedStringArray(OS.get_cmdline_user_args())
	if paths.is_empty():
		_collect_scripts("res://", paths)
	paths.sort()
	var failed := 0
	for path in paths:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			failed += 1
			print("FAIL %s" % path)
		else:
			print("ok   %s" % path)
	print("%d script(s) checked, %d failed" % [paths.size(), failed])
	quit(1 if failed > 0 else 0)


func _collect_scripts(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("cannot open %s" % dir_path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var full_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not SKIPPED_DIRS.has(entry):
				_collect_scripts(full_path, out)
		elif entry.ends_with(".gd"):
			out.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
