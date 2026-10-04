## App-wide history of runs, persisted as JSON Lines in user://, plus the few
## preferences that belong to it. Scenes record through [method record]; the
## logic lives in StatsHistory so it stays testable.
extends Node

const HISTORY_PATH := "user://results.jsonl"
const SETTINGS_PATH := "user://settings.cfg"
const EXPORT_PATH := "user://neuro-drills-results.csv"

var history: StatsHistory = StatsHistory.new()
## Whether the results screen asks for the perceived exertion (RPE 1-10).
var rpe_enabled: bool = true


func _ready() -> void:
	_load()


## Stores the result and returns its record (with the derived statistics).
func record(result: DrillResult) -> Dictionary:
	var entry := StatsHistory.make_record(result)
	history.add(entry)
	var file := FileAccess.open(HISTORY_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(HISTORY_PATH) else FileAccess.WRITE)
	if file == null:
		push_warning("StatsStore: cannot write %s (%s)" % [HISTORY_PATH, error_string(FileAccess.get_open_error())])
		return entry
	file.seek_end()
	file.store_string(StatsHistory.serialize_record(entry))
	file.close()
	return entry


func set_rpe(id: String, rpe: int) -> void:
	if history.set_rpe(id, rpe):
		_save_all()


## Writes the CSV export; on the web the browser downloads it instead.
## Returns the readable path of the written file, or "" on failure.
func export_csv() -> String:
	var csv := history.to_csv()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(csv.to_utf8_buffer(), EXPORT_PATH.get_file(), "text/csv")
		return EXPORT_PATH.get_file()
	var file := FileAccess.open(EXPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("StatsStore: cannot write %s (%s)" % [EXPORT_PATH, error_string(FileAccess.get_open_error())])
		return ""
	file.store_string(csv)
	file.close()
	return ProjectSettings.globalize_path(EXPORT_PATH)


## Forgets every stored run.
func clear() -> void:
	history = StatsHistory.new()
	if FileAccess.file_exists(HISTORY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(HISTORY_PATH))


func set_rpe_enabled(enabled: bool) -> void:
	rpe_enabled = enabled
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("results", "rpe_enabled", enabled)
	config.save(SETTINGS_PATH)


func _load() -> void:
	if FileAccess.file_exists(HISTORY_PATH):
		var text := FileAccess.get_file_as_string(HISTORY_PATH)
		history = StatsHistory.parse(text)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		rpe_enabled = config.get_value("results", "rpe_enabled", true)


func _save_all() -> void:
	var file := FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("StatsStore: cannot write %s (%s)" % [HISTORY_PATH, error_string(FileAccess.get_open_error())])
		return
	file.store_string(history.serialize())
	file.close()
