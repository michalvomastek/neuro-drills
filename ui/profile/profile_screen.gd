## Player profile: streak, level, daily goal, the last seven days and every
## badge with its description (earned ones bright, the rest dim).
class_name ProfileScreen
extends Control

@onready var _margin: MarginContainer = %Margin
@onready var _stats: HFlowContainer = %Stats
@onready var _week_label: Label = %WeekLabel
@onready var _badges_title: Label = %BadgesTitle
@onready var _badges: GridContainer = %Badges
@onready var _back_button: Button = %BackButton
@onready var _progress_button: Button = %ProgressButton


func _ready() -> void:
	_back_button.pressed.connect(SceneRouter.show_menu)
	_progress_button.pressed.connect(SceneRouter.show_progress)
	GamiWidgets.add_stats(_stats, false)
	var week := StatsStore.history.week_summary(int(Time.get_unix_time_from_system()))
	var week_runs: int = week["runs"]
	_week_label.text = tr("PROGRESS_WEEK") % [week_runs, week["minutes"], week["drills"], week["improved"]] if week_runs > 0 else tr("PROFILE_WEEK_EMPTY")
	var earned := StatsStore.earned_badges()
	_badges_title.text = tr("GAMI_BADGES") % [earned.size(), Gamification.BADGE_ORDER.size()]
	for id in Gamification.BADGE_ORDER:
		_add_badge(id, earned.has(id))
	Layout.watch(self, _relayout)
	_back_button.grab_focus()


func _relayout() -> void:
	var narrow := Layout.is_narrow(self)
	Layout.set_margins(_margin, Layout.side_margin(self), 12 if narrow else 32)
	_badges.columns = 1 if narrow else 3


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneRouter.show_menu()
		get_viewport().set_input_as_handled()


func _add_badge(id: String, earned: bool) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"Card" if earned else &"Sunken"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var name := Label.new()
	name.text = tr("BADGE_%s" % id.to_upper())
	name.theme_type_variation = &"HeadingLabel" if earned else &"DimLabel"
	name.add_theme_font_size_override("font_size", 20)
	box.add_child(name)
	var description := Label.new()
	description.text = tr("BADGE_%s_DESC" % id.to_upper())
	description.theme_type_variation = &"DimLabel"
	description.add_theme_font_size_override("font_size", 16)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	var state := Label.new()
	state.text = tr("PROFILE_BADGE_EARNED" if earned else "PROFILE_BADGE_LOCKED")
	state.theme_type_variation = &"PillLabel" if earned else &"DimLabel"
	state.add_theme_color_override("font_color", get_theme_color("green" if earned else "dim", "App"))
	state.add_theme_font_size_override("font_size", 15)
	box.add_child(state)
	_badges.add_child(card)
