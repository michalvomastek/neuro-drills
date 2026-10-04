## Notes the maintainer wrote inside the app: write a new one, read the old
## ones, copy or export them all as text.
class_name FeedbackScreen
extends Control

@onready var _edit: TextEdit = %NoteEdit
@onready var _save_button: Button = %SaveButton
@onready var _list: VBoxContainer = %NoteList
@onready var _empty_label: Label = %EmptyLabel
@onready var _copy_button: Button = %CopyButton
@onready var _export_button: Button = %ExportButton
@onready var _status_label: Label = %StatusLabel
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_back_button.pressed.connect(SceneRouter.show_menu)
	_save_button.pressed.connect(_on_save_pressed)
	_copy_button.pressed.connect(_on_copy_pressed)
	_export_button.pressed.connect(_on_export_pressed)
	_edit.placeholder_text = tr("FEEDBACK_PLACEHOLDER")
	_rebuild()
	_edit.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneRouter.show_menu()
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	var notes := StatsStore.feedback.sorted()
	_empty_label.visible = notes.is_empty()
	_copy_button.disabled = notes.is_empty()
	_export_button.disabled = notes.is_empty()
	for note in notes:
		_list.add_child(_make_entry(note))


func _make_entry(note: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var meta := Label.new()
	var at: int = note["at"]
	var context: Dictionary = note["context"]
	var meta_text := Time.get_datetime_string_from_unix_time(at, true)
	if context.has("drill"):
		meta_text += " · " + FeedbackLog.text_of(context["drill"])
		var variant := FeedbackLog.text_of(context.get("variant", ""))
		if not variant.is_empty():
			meta_text += " (%s)" % variant
	meta.text = meta_text
	meta.theme_type_variation = &"DimLabel"
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(meta)
	var send_button := Button.new()
	send_button.text = tr("FEEDBACK_SEND_GITHUB")
	send_button.flat = true
	send_button.pressed.connect(func() -> void: OS.shell_open(FeedbackLog.issue_url(note)))
	header.add_child(send_button)
	var delete_button := Button.new()
	delete_button.text = tr("FEEDBACK_DELETE")
	delete_button.flat = true
	var id: String = note["id"]
	delete_button.pressed.connect(func() -> void:
		StatsStore.remove_note(id)
		_rebuild())
	header.add_child(delete_button)
	if context.has("result"):
		var result := Label.new()
		result.text = FeedbackLog.text_of(context["result"])
		result.theme_type_variation = &"DimLabel"
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(result)
	var text := Label.new()
	text.text = FeedbackLog.text_of(note["text"])
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	return panel


func _on_save_pressed() -> void:
	if _edit.text.strip_edges().is_empty():
		return
	StatsStore.add_note(_edit.text, {"drill": tr("FEEDBACK_GENERAL")})
	_edit.text = ""
	_status_label.text = tr("FEEDBACK_SAVED")
	_rebuild()


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(StatsStore.feedback.to_text())
	_status_label.text = tr("FEEDBACK_COPIED")


func _on_export_pressed() -> void:
	var path := StatsStore.export_feedback()
	_status_label.text = tr("PROGRESS_EXPORTED") % path if not path.is_empty() else tr("PROGRESS_EXPORT_FAILED")
