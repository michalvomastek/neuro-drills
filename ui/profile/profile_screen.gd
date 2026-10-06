## Player profile: streak, level, daily goal, the last seven days and every
## badge with its description (earned ones bright, the rest dim).
class_name ProfileScreen
extends Control

const BADGE_ICON_SIZE := 56.0

@onready var _margin: MarginContainer = %Margin
@onready var _stats: VBoxContainer = %Stats
@onready var _week_label: Label = %WeekLabel
@onready var _badges_title: Label = %BadgesTitle
@onready var _badges: GridContainer = %Badges


func _ready() -> void:
	GamiWidgets.add_profile_stats(_stats)
	var week := StatsStore.history.week_summary(int(Time.get_unix_time_from_system()))
	var week_runs: int = week["runs"]
	_week_label.text = tr("PROGRESS_WEEK") % [week_runs, week["minutes"], week["drills"], week["improved"]] if week_runs > 0 else tr("PROFILE_WEEK_EMPTY")
	var earned := StatsStore.earned_badges()
	_badges_title.text = tr("GAMI_BADGES") % [earned.size(), Gamification.BADGE_ORDER.size()]
	for id in Gamification.BADGE_ORDER:
		_add_badge(id, earned.has(id))
	Layout.watch(self, _relayout)


func _relayout() -> void:
	var narrow := Layout.is_narrow(self)
	Layout.set_screen_margins(_margin)
	_badges.columns = 1 if narrow else 2


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneRouter.show_menu()
		get_viewport().set_input_as_handled()


func _add_badge(id: String, earned: bool) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"Card" if earned else &"Sunken"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	row.add_child(GamiWidgets.make_badge_icon(id, BADGE_ICON_SIZE, earned))
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	row.add_child(box)
	var name := Label.new()
	name.text = tr("BADGE_%s" % id.to_upper())
	name.theme_type_variation = &"ItemLabel"
	if not earned:
		name.add_theme_color_override("font_color", get_theme_color("dim", "App"))
	box.add_child(name)
	var description := Label.new()
	description.text = tr("BADGE_%s_DESC" % id.to_upper())
	description.theme_type_variation = &"NoteLabel"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	var state := Label.new()
	state.text = tr("PROFILE_BADGE_EARNED" if earned else "PROFILE_BADGE_LOCKED")
	state.theme_type_variation = &"PillLabel" if earned else &"DimLabel"
	state.add_theme_color_override("font_color", get_theme_color("green" if earned else "dim", "App"))
	state.add_theme_font_size_override("font_size", 15)
	box.add_child(state)
	_badges.add_child(card)
