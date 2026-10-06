## Lists the registered drills in one tab per category; the player's numbers
## sit in the app's top bar and the other destinations in the bottom bar.
extends Control

@onready var _margin: MarginContainer = %Center
@onready var _tabs: TabContainer = %Tabs
@onready var _tab_strip: ScrollContainer = %TabStrip
@onready var _tab_buttons: HBoxContainer = %TabButtons

var _first_buttons: Array[Button] = []
var _strip_buttons: Array[Button] = []
var _grids: Array[GridContainer] = []


func _ready() -> void:
	for category in DrillRegistry.CATEGORY_ORDER:
		var definitions := DrillRegistry.get_by_category(category)
		if definitions.is_empty():
			continue
		_add_category_tab(category, definitions)
	_tabs.current_tab = clampi(DrillRegistry.last_menu_tab, 0, maxi(0, _tabs.get_tab_count() - 1))
	_build_tab_strip()
	_tabs.tab_changed.connect(_on_tab_changed)
	Layout.watch(self, _relayout)
	_focus_current_tab()


## One column and slim margins on a phone, two columns and wide margins otherwise.
func _relayout() -> void:
	var narrow := Layout.is_narrow(self)
	Layout.set_screen_margins(_margin)
	for grid in _grids:
		grid.columns = 1 if narrow else 2
	# The tab bar can only be paged with its small arrows; a phone gets a
	# strip of pills that scrolls by dragging instead.
	_tabs.tabs_visible = not narrow
	_tab_strip.visible = narrow
	_tabs.clip_tabs = narrow


## One tab per category: a scrollable two-column grid with a short tab title
## and the full category name as a heading inside.
func _add_category_tab(category_key: String, definitions: Array[DrillDefinition]) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = tr(category_key + "_SHORT")
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	var heading := Label.new()
	heading.text = tr(category_key)
	heading.theme_type_variation = &"DimLabel"
	heading.add_theme_font_size_override("font_size", 22)
	column.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	column.add_child(grid)
	_grids.append(grid)
	var first: Button = null
	for definition in definitions:
		var button := _add_drill_entry(grid, definition)
		if first == null:
			first = button
	_first_buttons.append(first)


func _on_tab_changed(tab: int) -> void:
	DrillRegistry.last_menu_tab = tab
	_update_tab_strip()
	_focus_current_tab()


## One pill per category, mirroring the tab bar.
func _build_tab_strip() -> void:
	for i in _tabs.get_tab_count():
		var button := Button.new()
		button.text = _tabs.get_tab_title(i)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void:
			_tabs.current_tab = i
			_update_tab_strip())
		_tab_buttons.add_child(button)
		_strip_buttons.append(button)
	_update_tab_strip()


func _update_tab_strip() -> void:
	for i in _strip_buttons.size():
		var selected := i == _tabs.current_tab
		_strip_buttons[i].button_pressed = selected
		_strip_buttons[i].theme_type_variation = &"SmallPrimaryButton" if selected else &"SmallButton"
	if _tabs.current_tab >= 0 and _tabs.current_tab < _strip_buttons.size():
		_tab_strip.ensure_control_visible(_strip_buttons[_tabs.current_tab])


func _focus_current_tab() -> void:
	# A focus outline on the first card reads as a selection on a phone.
	if DragScroll.touch_ui():
		return
	var index := _tabs.current_tab
	if index >= 0 and index < _first_buttons.size() and _first_buttons[index] != null:
		_first_buttons[index].grab_focus()


## One card per drill, the whole card is the button: title and description
## inside. A Button does not size itself to children, so the card follows
## the minimum size of its text column.
func _add_drill_entry(grid: GridContainer, definition: DrillDefinition) -> Button:
	var card := Button.new()
	card.theme_type_variation = &"CardButton"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.pressed.connect(SceneRouter.start_drill.bind(definition.id))
	grid.add_child(card)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	var style := card.get_theme_stylebox("normal")
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = style.get_margin(SIDE_LEFT)
	column.offset_top = style.get_margin(SIDE_TOP)
	column.offset_right = -style.get_margin(SIDE_RIGHT)
	column.offset_bottom = -style.get_margin(SIDE_BOTTOM)
	card.add_child(column)
	var title := Label.new()
	title.text = tr(definition.title_key)
	title.theme_type_variation = &"HeadingLabel"
	title.add_theme_font_size_override("font_size", 20)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var description := Label.new()
	description.text = Drill.describe(definition.description_key)
	description.theme_type_variation = &"DimLabel"
	description.add_theme_font_size_override("font_size", 16)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(description)
	var fit := func() -> void:
		card.custom_minimum_size = Vector2(0, column.get_combined_minimum_size().y + style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM))
	column.minimum_size_changed.connect(fit)
	fit.call()
	return card
