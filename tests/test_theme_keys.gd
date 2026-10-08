## Every colour, stylebox, constant or font that a script asks for by name
## and type (Control.get_theme_*, Theme.get_*) must exist in both generated
## themes, and so must every theme_type_variation named in a script or
## scene. A lookup that misses returns black (or the engine default) without
## any error: dropping the Board type from make_theme.gd once left every
## drawn board black for two days.
extends TestCase

const THEMES: Array[String] = ["res://ui/theme/dark_theme.tres", "res://ui/theme/light_theme.tres"]
const SOURCE_DIRS: Array[String] = ["res://autoload", "res://core", "res://drills", "res://ui"]
const CALL_PATTERN := "(?:get|has)_(?:theme_)?(color|stylebox|constant|font_size|font)\\(([^()]*(?:\\([^()]*\\)[^()]*)*)\\)"
const STRING_PATTERN := "\"([A-Za-z0-9_]+)\""


func test_named_lookups_exist_in_both_themes() -> void:
	var lookups := _collect_lookups()
	assert_true(lookups.size() > 20, "found only %d lookups" % lookups.size())
	for path in THEMES:
		var theme := load(path) as Theme
		assert_true(theme != null, path)
		if theme == null:
			continue
		for lookup in lookups:
			var kind: String = lookup["kind"]
			var name: StringName = lookup["name"]
			var type: StringName = lookup["type"]
			assert_true(_has_in_chain(theme, kind, name, type), "%s lacks %s %s/%s (%s)" % [path.get_file(), kind, type, name, lookup["where"]])


func test_variations_exist_in_both_themes() -> void:
	var variations := _collect_variations()
	assert_true(variations.size() > 10, "found only %d variations" % variations.size())
	for path in THEMES:
		var theme := load(path) as Theme
		if theme == null:
			continue
		for type: StringName in variations:
			assert_true(theme.is_type_variation(type, theme.get_type_variation_base(type)) or ClassDB.class_exists(type), "%s lacks variation %s (%s)" % [path.get_file(), type, variations[type]])


## Walks the variation and class chain the way Control.get_theme_*() does,
## consulting the engine's default theme for engine types.
func _has_in_chain(theme: Theme, kind: String, name: StringName, type: StringName) -> bool:
	var current := type
	while not current.is_empty():
		if _has(theme, kind, name, current) or _has(ThemeDB.get_default_theme(), kind, name, current):
			return true
		var base := theme.get_type_variation_base(current)
		if base.is_empty() and ClassDB.class_exists(current):
			base = ClassDB.get_parent_class(current)
		current = base
	return false


func _has(theme: Theme, kind: String, name: StringName, type: StringName) -> bool:
	match kind:
		"color":
			return theme.has_color(name, type)
		"stylebox":
			return theme.has_stylebox(name, type)
		"constant":
			return theme.has_constant(name, type)
		"font_size":
			return theme.has_font_size(name, type)
		"font":
			return theme.has_font(name, type)
	return false


## Explicit lookups: the last string literal in the call is the type, the
## others are names; a literal right after a comparison is an ordinary value.
func _collect_lookups() -> Array[Dictionary]:
	var lookups: Array[Dictionary] = []
	var call := RegEx.create_from_string(CALL_PATTERN)
	var literal := RegEx.create_from_string(STRING_PATTERN)
	for path in _source_files():
		var source := FileAccess.get_file_as_string(path)
		for found in call.search_all(source):
			var args := found.get_string(2)
			var names: Array[String] = []
			for part in literal.search_all(args):
				var before := args.substr(0, part.get_start()).strip_edges()
				if before.ends_with("==") or before.ends_with("!="):
					continue
				names.append(part.get_string(1))
			if names.size() < 2:
				continue
			var type := names.pop_back() as String
			for name in names:
				lookups.append({"kind": found.get_string(1), "name": StringName(name), "type": StringName(type), "where": path.get_file()})
	return lookups


## theme_type_variation assignments in scripts and scenes -> where they
## appear; every literal of the right-hand side counts, a conditional names two.
func _collect_variations() -> Dictionary:
	var variations := {}
	var assignment := RegEx.create_from_string("theme_type_variation\\s*=\\s*(.+)")
	var literal := RegEx.create_from_string(STRING_PATTERN)
	for path in _source_files() + _scene_files():
		var source := FileAccess.get_file_as_string(path)
		for found in assignment.search_all(source):
			for part in literal.search_all(found.get_string(1)):
				variations[StringName(part.get_string(1))] = path.get_file()
	return variations


func _source_files() -> Array[String]:
	var files: Array[String] = []
	for dir in SOURCE_DIRS:
		_walk(dir, "gd", files)
	return files


func _scene_files() -> Array[String]:
	var files: Array[String] = []
	for dir in SOURCE_DIRS:
		_walk(dir, "tscn", files)
	return files


func _walk(dir: String, extension: String, files: Array[String]) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == extension:
			files.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		_walk(dir.path_join(sub), extension, files)
