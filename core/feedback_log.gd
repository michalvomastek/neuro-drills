## Notes the maintainer writes inside the app (bug reports, ideas), with the
## context of the moment they were written. Pure logic; StatsStore persists
## the notes as JSON Lines next to the run history.
class_name FeedbackLog
extends RefCounted

var notes: Array[Dictionary] = []


## Builds a note. [param context] holds free String -> String pairs such as
## "drill", "variant", "result", "platform", "screen", "locale".
static func make_note(text: String, context: Dictionary, at: int) -> Dictionary:
	return {
		"id": "%d-%d" % [at, randi() % 1000000],
		"at": at,
		"text": text.strip_edges(),
		"context": context.duplicate(),
	}


## Environment of the running app, shared by every note.
static func environment() -> Dictionary:
	var platform := OS.get_name()
	if OS.has_feature("web"):
		platform += " (web)"
	var window := DisplayServer.window_get_size()
	return {
		"platform": platform,
		"screen": "%d×%d" % [window.x, window.y],
		"locale": TranslationServer.get_locale(),
		"touch": "yes" if DisplayServer.is_touchscreen_available() else "no",
	}


## A stored value as text (JSON may hand back any Variant).
static func text_of(value: Variant) -> String:
	return str(value) if value != null else ""


func add(note: Dictionary) -> void:
	notes.append(note)


func remove(id: String) -> bool:
	for i in notes.size():
		if notes[i]["id"] == id:
			notes.remove_at(i)
			return true
	return false


## Newest first.
func sorted() -> Array[Dictionary]:
	var out := notes.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var at_a: int = a["at"]
		var at_b: int = b["at"]
		return at_a > at_b)
	return out


## Plain text of every note, newest first, ready to paste into a chat.
func to_text() -> String:
	var blocks := PackedStringArray()
	for note in sorted():
		blocks.append(format_note(note))
	return "\n\n".join(blocks) + ("\n" if not blocks.is_empty() else "")


static func format_note(note: Dictionary) -> String:
	var at: int = note["at"]
	var context: Dictionary = note["context"]
	var lines := PackedStringArray()
	var heading := "## " + Time.get_datetime_string_from_unix_time(at, true)
	if context.has("drill"):
		heading += " · " + FeedbackLog.text_of(context["drill"])
		if context.has("variant") and not FeedbackLog.text_of(context["variant"]).is_empty():
			heading += " (" + FeedbackLog.text_of(context["variant"]) + ")"
	lines.append(heading)
	if context.has("result"):
		lines.append(FeedbackLog.text_of(context["result"]))
	var env := PackedStringArray()
	for key: String in ["platform", "screen", "locale", "touch"]:
		if context.has(key):
			env.append(FeedbackLog.text_of(context[key]))
	if not env.is_empty():
		lines.append(", ".join(env))
	lines.append("")
	lines.append(FeedbackLog.text_of(note["text"]))
	return "\n".join(lines)


func serialize() -> String:
	var lines := PackedStringArray()
	for note in notes:
		lines.append(JSON.stringify(note))
	return "\n".join(lines) + ("\n" if not lines.is_empty() else "")


static func parse(text: String) -> FeedbackLog:
	var log := FeedbackLog.new()
	for line in text.split("\n", false):
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			var note: Dictionary = parsed
			if note.has("id") and note.has("text") and note.has("at"):
				var at: float = note["at"]
				note["at"] = int(at)
				if not note.has("context") or not note["context"] is Dictionary:
					note["context"] = {}
				log.notes.append(note)
	return log
