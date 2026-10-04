## Dialog with a text box for one feedback note; saves through StatsStore.
class_name NoteDialog
extends ConfirmationDialog

signal saved

const DIALOG_SIZE := Vector2i(600, 300)
const SCREEN_GAP := 16

var _edit: TextEdit
var _hint: Label
var _context: Dictionary = {}
var _size: Vector2i = DIALOG_SIZE


## [param screen_size] is the viewport size in design units; the dialog is
## capped to it on a phone. It is needed before the dialog enters the tree,
## because a wrapping label without a known width reports a huge minimum
## height and the window would grow past the screen.
func _init(screen_size: Vector2 = Vector2(DIALOG_SIZE)) -> void:
	var available := screen_size - Vector2(SCREEN_GAP, SCREEN_GAP) * 2.0
	_size = Vector2i(mini(DIALOG_SIZE.x, int(available.x)), mini(DIALOG_SIZE.y, int(available.y)))
	title = tr("FEEDBACK_NOTE_TITLE")
	ok_button_text = tr("FEEDBACK_SAVE")
	cancel_button_text = tr("COMMON_BACK")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_hint = Label.new()
	_hint.text = tr("FEEDBACK_HINT")
	_hint.theme_type_variation = &"DimLabel"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(_size.x - 40, 0)
	box.add_child(_hint)
	_edit = TextEdit.new()
	_edit.custom_minimum_size = Vector2(0, 150)
	_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_edit.placeholder_text = tr("FEEDBACK_PLACEHOLDER")
	box.add_child(_edit)
	add_button(tr("FEEDBACK_SEND_GITHUB"), true, "send")
	custom_action.connect(_on_custom_action)
	confirmed.connect(_on_confirmed)
	visibility_changed.connect(func() -> void:
		if not visible:
			queue_free())


func open(context: Dictionary) -> void:
	_context = context
	popup_centered(_size)
	_edit.grab_focus()


func _on_confirmed() -> void:
	_save()


func _on_custom_action(action: StringName) -> void:
	if action != &"send":
		return
	var note := _save()
	if not note.is_empty():
		OS.shell_open(FeedbackLog.issue_url(note))
	hide()


func _save() -> Dictionary:
	if _edit.text.strip_edges().is_empty():
		return {}
	var note := StatsStore.add_note(_edit.text, _context)
	saved.emit()
	return note
