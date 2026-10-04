## App-wide history of runs, persisted as JSON Lines in user://, plus the few
## preferences that belong to it. Scenes record through [method record]; the
## logic lives in StatsHistory so it stays testable.
extends Node

const HISTORY_PATH := "user://results.jsonl"
const SETTINGS_PATH := "user://settings.cfg"
const EXPORT_PATH := "user://neuro-drills-results.csv"
const FEEDBACK_PATH := "user://feedback.jsonl"
const FEEDBACK_EXPORT_PATH := "user://neuro-drills-feedback.txt"

var history: StatsHistory = StatsHistory.new()
var feedback: FeedbackLog = FeedbackLog.new()
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
	return _export(EXPORT_PATH, history.to_csv(), "text/csv")


func _export(path: String, content: String, mime: String) -> String:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(content.to_utf8_buffer(), path.get_file(), mime)
		return path.get_file()
	if not _write(path, content):
		return ""
	return ProjectSettings.globalize_path(path)


func _write(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("StatsStore: cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(content)
	file.close()
	return true


## Forgets every stored run.
func clear() -> void:
	history = StatsHistory.new()
	if FileAccess.file_exists(HISTORY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(HISTORY_PATH))


## Stores a feedback note with the app environment merged into [param context].
func add_note(text: String, context: Dictionary = {}) -> Dictionary:
	var full := FeedbackLog.environment()
	full.merge(context, true)
	var note := FeedbackLog.make_note(text, full, int(Time.get_unix_time_from_system()))
	feedback.add(note)
	_write(FEEDBACK_PATH, feedback.serialize())
	return note


func remove_note(id: String) -> void:
	if feedback.remove(id):
		_write(FEEDBACK_PATH, feedback.serialize())


## Writes the notes as plain text; on the web the browser downloads it.
## Returns the readable path, the file name on the web, or "" on failure.
func export_feedback() -> String:
	return _export(FEEDBACK_EXPORT_PATH, feedback.to_text(), "text/plain")


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
	if FileAccess.file_exists(FEEDBACK_PATH):
		feedback = FeedbackLog.parse(FileAccess.get_file_as_string(FEEDBACK_PATH))
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		rpe_enabled = config.get_value("results", "rpe_enabled", true)


func _save_all() -> void:
	_write(HISTORY_PATH, history.serialize())
