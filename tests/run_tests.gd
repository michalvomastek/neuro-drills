## Minimal headless test runner, started by `tools/godot.sh test`.
## Loads every res://tests/test_*.gd (each must extend TestCase) and runs its
## methods whose names start with "test_". Exit code 1 when anything fails.
extends SceneTree

const TESTS_DIR := "res://tests"


func _initialize() -> void:
	var test_count := 0
	var failed_count := 0
	for path in _find_test_files():
		var script := load(path) as GDScript
		var instance: TestCase = script.new() as TestCase if script != null else null
		if instance == null:
			push_error("%s does not extend TestCase" % path)
			failed_count += 1
			continue
		for method in instance.get_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			test_count += 1
			instance.begin_test()
			instance.before_each()
			instance.call(method_name)
			var failures := instance.end_test()
			if failures.is_empty():
				print("ok   %s::%s" % [path.get_file(), method_name])
			else:
				failed_count += 1
				print("FAIL %s::%s" % [path.get_file(), method_name])
				for failure in failures:
					print("     %s" % failure)
	print("%d test(s), %d failed" % [test_count, failed_count])
	quit(1 if failed_count > 0 or test_count == 0 else 0)


func _find_test_files() -> PackedStringArray:
	var files := PackedStringArray()
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		push_error("cannot open %s" % TESTS_DIR)
		return files
	for file_name in dir.get_files():
		if file_name.begins_with("test_") and file_name.ends_with(".gd") and file_name != "test_case.gd":
			files.append(TESTS_DIR.path_join(file_name))
	files.sort()
	return files
