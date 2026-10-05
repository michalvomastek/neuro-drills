## App-wide history of runs, persisted as JSON Lines in user://, plus the few
## preferences that belong to it. Scenes record through [method record]; the
## logic lives in StatsHistory so it stays testable.
extends Node

const HISTORY_PATH := "user://results.jsonl"
const SETTINGS_PATH := "user://settings.cfg"
const EXPORT_PATH := "user://neuro-drills-results.csv"
const BACKUP_PATH := "user://neuro-drills-results.jsonl"
const FEEDBACK_PATH := "user://feedback.jsonl"
const FEEDBACK_EXPORT_PATH := "user://neuro-drills-feedback.txt"
const PLANS_PATH := "user://plans.json"

var history: StatsHistory = StatsHistory.new()
var feedback: FeedbackLog = FeedbackLog.new()
## Saved training plans: {"name", "steps"}.
var plans: Array[Dictionary] = []
## Length of a suggested training, minutes.
var training_minutes: int = 10
## Whether the results screen asks for the perceived exertion (RPE 1-10).
var rpe_enabled: bool = true
## Feedback sounds (correct / wrong / finished).
var sound_enabled: bool = true
## Name of the active theme: "dark" or "light" (ui/theme/<name>_theme.tres).
var theme_name: String = "dark"

## Badges already shown to the player; a newly earned one is announced once.
var badges_seen: PackedStringArray = []

signal theme_changed(theme_name: String)


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


## Writes the raw history (JSON Lines) for a backup or for another device.
func export_backup() -> String:
	return _export(BACKUP_PATH, history.serialize(), "application/x-ndjson")


## Merges a backup (the JSON Lines text) into the history; returns how many
## runs were new, or -1 when the text held no run at all.
func import_backup(text: String) -> int:
	var other := StatsHistory.parse(text)
	if other.records.is_empty():
		return -1
	var added := history.merge(other)
	if added > 0:
		_save_all()
	return added


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
	badges_seen = PackedStringArray()
	_set_setting("gamification", "badges_seen", badges_seen)
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
	_set_setting("results", "rpe_enabled", enabled)


func set_sound_enabled(on: bool) -> void:
	sound_enabled = on
	_set_setting("sound", "enabled", on)
	Sfx.enabled = on


func set_theme_name(name: String) -> void:
	theme_name = "light" if name == "light" else "dark"
	_set_setting("ui", "theme", theme_name)
	theme_changed.emit(theme_name)


## Local time zone offset for day boundaries, minutes east of UTC.
static func tz_bias_min() -> int:
	var zone := Time.get_time_zone_from_system()
	var bias: int = zone.get("bias", 0)
	return bias


func current_streak(now_unix: int = int(Time.get_unix_time_from_system())) -> int:
	return Gamification.streak(history.records, now_unix, tz_bias_min())


## Minutes played today, rounded down.
func minutes_today(now_unix: int = int(Time.get_unix_time_from_system())) -> int:
	return Gamification.seconds_on_day(history.records, now_unix, tz_bias_min()) / 60


func level_info() -> Dictionary:
	return Gamification.level_for_xp(Gamification.total_xp(history.records))


## Ids of all earned badges, in display order.
func earned_badges(now_unix: int = int(Time.get_unix_time_from_system())) -> Array[String]:
	var categories: Dictionary = {}
	var category_keys: Dictionary = {}
	for definition in DrillRegistry.get_all():
		categories[String(definition.id)] = definition.category_key
		category_keys[definition.category_key] = true
	return Gamification.badges(history.records, now_unix, tz_bias_min(), training_minutes, categories, category_keys.size())


## Earned badges not announced yet; marks them as seen.
func take_new_badges() -> Array[String]:
	var fresh: Array[String] = []
	for id in earned_badges():
		if not badges_seen.has(id):
			fresh.append(id)
			badges_seen.append(id)
	if not fresh.is_empty():
		_set_setting("gamification", "badges_seen", badges_seen)
	return fresh


func set_training_minutes(minutes: int) -> void:
	training_minutes = clampi(minutes, TrainingPlan.MIN_MINUTES, TrainingPlan.MAX_MINUTES)
	_set_setting("training", "minutes", training_minutes)


## Adds or replaces the plan called [param plan_name].
func save_plan(plan_name: String, steps: Array[Dictionary]) -> void:
	delete_plan(plan_name)
	plans.append({"name": plan_name, "steps": steps.duplicate(true)})
	_write(PLANS_PATH, TrainingPlan.serialize_plans(plans))


func delete_plan(plan_name: String) -> void:
	for i in range(plans.size() - 1, -1, -1):
		if plans[i]["name"] == plan_name:
			plans.remove_at(i)
	_write(PLANS_PATH, TrainingPlan.serialize_plans(plans))


func find_plan(plan_name: String) -> Dictionary:
	for plan in plans:
		if plan["name"] == plan_name:
			return plan
	return {}


func _set_setting(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(section, key, value)
	config.save(SETTINGS_PATH)


func _load() -> void:
	if FileAccess.file_exists(HISTORY_PATH):
		var text := FileAccess.get_file_as_string(HISTORY_PATH)
		history = StatsHistory.parse(text)
	if FileAccess.file_exists(FEEDBACK_PATH):
		feedback = FeedbackLog.parse(FileAccess.get_file_as_string(FEEDBACK_PATH))
	if FileAccess.file_exists(PLANS_PATH):
		plans = TrainingPlan.parse_plans(FileAccess.get_file_as_string(PLANS_PATH))
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		rpe_enabled = config.get_value("results", "rpe_enabled", true)
		training_minutes = config.get_value("training", "minutes", 10)
		theme_name = config.get_value("ui", "theme", "dark")
		sound_enabled = config.get_value("sound", "enabled", true)
		badges_seen = config.get_value("gamification", "badges_seen", PackedStringArray())


func _save_all() -> void:
	_write(HISTORY_PATH, history.serialize())
