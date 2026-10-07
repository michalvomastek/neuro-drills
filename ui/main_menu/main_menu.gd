## Lists the registered drills filtered by a strip of category pills (first
## "All", then one page per category); the player's numbers
## sit in the app's top bar and the other destinations in the bottom bar.
extends Control

@onready var _strip_frame: MarginContainer = %StripFrame
@onready var _tabs: TabContainer = %Tabs
@onready var _tab_strip: ScrollContainer = %TabStrip
@onready var _tab_buttons: HBoxContainer = %TabButtons
@onready var _strip_margin: MarginContainer = %StripMargin

var _first_buttons: Array[Button] = []
var _strip_buttons: Array[Button] = []
var _grids: Array[GridContainer] = []
## Margins of the tab contents: the lists scroll edge to edge, right up to
## the bottom bar (so the scroll indicator sits at the window edge like on
## every other screen), and the content keeps the screen margin inside.
var _tab_margins: Array[MarginContainer] = []
## Room under the pinned filter strip (the TabContainer's own top padding
## is zeroed in _ready, so this is the whole gap).
const STRIP_GAP := 12


func _ready() -> void:
	# The category filter is the strip of pills on every screen size; the
	# tab bar itself stays hidden (its arrows were the only way to page).
	_tabs.tabs_visible = false
	_tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_add_all_tab()
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


## One column and slim margins on a phone, two columns and wide margins
## otherwise. The filter strip is pinned under the top bar; the screen
## margins (plus the Screen panel's padding the other screens get from
## their PanelContainer) sit inside the strip and inside the scrolling lists.
func _relayout() -> void:
	var narrow := Layout.is_narrow(self)
	var screen := get_theme_stylebox("panel", "Screen")
	var side := Layout.side_margin(self) + roundi(screen.get_margin(SIDE_LEFT))
	var top := (Layout.SCREEN_MARGIN_NARROW if narrow else Layout.SCREEN_MARGIN_WIDE) + roundi(screen.get_margin(SIDE_TOP))
	var bottom := (Layout.SCREEN_MARGIN_NARROW if narrow else Layout.SCREEN_MARGIN_WIDE) + roundi(screen.get_margin(SIDE_BOTTOM))
	Layout.set_margins_each(_strip_frame, 0, top, STRIP_GAP)
	Layout.set_margins_each(_strip_margin, side, 0, 0)
	for tab_margin in _tab_margins:
		Layout.set_margins_each(tab_margin, side, 0, bottom)
	for grid in _grids:
		grid.columns = 1 if narrow else 2


## A scrollable tab page: the margin that keeps the screen's side margin
## inside the edge-to-edge list, and the column the sections go into.
func _add_tab_page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var tab_margin := MarginContainer.new()
	tab_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(tab_margin)
	_tab_margins.append(tab_margin)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	tab_margin.add_child(column)
	return column


## One section: the full category name as a heading and the grid of cards.
func _add_category_section(column: VBoxContainer, category_key: String, definitions: Array[DrillDefinition]) -> Button:
	var heading := Label.new()
	heading.text = tr(category_key)
	heading.theme_type_variation = &"HeadingLabel"
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
	return first


## The first filter shows every category in one page.
func _add_all_tab() -> void:
	var column := _add_tab_page(tr("MENU_ALL_DRILLS"))
	var first: Button = null
	for category in DrillRegistry.CATEGORY_ORDER:
		var definitions := DrillRegistry.get_by_category(category)
		if definitions.is_empty():
			continue
		var button := _add_category_section(column, category, definitions)
		if first == null:
			first = button
	_first_buttons.append(first)


## One tab per category with a short pill title.
func _add_category_tab(category_key: String, definitions: Array[DrillDefinition]) -> void:
	var column := _add_tab_page(tr(category_key + "_SHORT"))
	_first_buttons.append(_add_category_section(column, category_key, definitions))


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
		_strip_buttons[i].theme_type_variation = &"PrimaryButton" if selected else &"Button"
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
	title.theme_type_variation = &"ItemLabel"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var description := Label.new()
	description.text = Drill.describe(definition.description_key)
	description.theme_type_variation = &"NoteLabel"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(description)
	var fit := func() -> void:
		card.custom_minimum_size = Vector2(0, column.get_combined_minimum_size().y + style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM))
	column.minimum_size_changed.connect(fit)
	fit.call()
	return card
