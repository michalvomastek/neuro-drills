## Settings of one Schulte table run. Converts to and from a plain Dictionary
## so the configuration travels inside DrillResult and can be persisted.
class_name SchulteConfig
extends RefCounted

const MIN_GRID_SIZE := 3
const MAX_GRID_SIZE := 7
const DEFAULT_GRID_SIZE := 5
## Letters are limited to the alphabet, so letter tables stop at 5x5.
const MAX_LETTER_GRID_SIZE := 5
## The Gorbov-Schulte red-black table is always 7x7: 25 black and 24 red numbers.
const RED_BLACK_GRID_SIZE := 7
const TEST_TABLE_COUNT := 5

const SYMBOLS_NUMBERS := "numbers"
const SYMBOLS_LETTERS := "letters"

var grid_size: int = DEFAULT_GRID_SIZE
var symbols: String = SYMBOLS_NUMBERS
var countdown: bool = true
var fixation_dot: bool = false
var show_next_target: bool = false
var dim_found: bool = false
## Red flash on a wrong cell plus a running error counter next to the target label.
var show_errors: bool = true
## Green flash on a correctly clicked cell.
var highlight_correct: bool = true
## Running timer in the top bar while playing.
var show_timer: bool = false
## Search from the highest symbol down to 1.
var reverse: bool = false
## Reshuffle the whole table after every correct click (dynamic table).
var shuffle_after_click: bool = false
## Gorbov-Schulte: black ascending and red descending, alternating.
var red_black: bool = false
## Schulte test: five tables in a row with efficiency, warm-up and stability indices.
var test_mode: bool = false


static func from_dict(data: Dictionary) -> SchulteConfig:
	var config := SchulteConfig.new()
	if data.has("grid_size"):
		var requested: int = data["grid_size"]
		config.grid_size = clampi(requested, MIN_GRID_SIZE, MAX_GRID_SIZE)
	config.symbols = data.get("symbols", config.symbols)
	if config.symbols != SYMBOLS_LETTERS:
		config.symbols = SYMBOLS_NUMBERS
	config.countdown = data.get("countdown", config.countdown)
	config.fixation_dot = data.get("fixation_dot", config.fixation_dot)
	config.show_next_target = data.get("show_next_target", config.show_next_target)
	config.dim_found = data.get("dim_found", config.dim_found)
	config.show_errors = data.get("show_errors", config.show_errors)
	config.highlight_correct = data.get("highlight_correct", config.highlight_correct)
	config.show_timer = data.get("show_timer", config.show_timer)
	config.reverse = data.get("reverse", config.reverse)
	config.shuffle_after_click = data.get("shuffle_after_click", config.shuffle_after_click)
	config.red_black = data.get("red_black", config.red_black)
	config.test_mode = data.get("test_mode", config.test_mode)
	config.normalize()
	return config


## Resolves conflicting choices: letters cap the grid, red-black fixes it.
func normalize() -> void:
	if red_black:
		grid_size = RED_BLACK_GRID_SIZE
		symbols = SYMBOLS_NUMBERS
	elif symbols == SYMBOLS_LETTERS:
		grid_size = mini(grid_size, MAX_LETTER_GRID_SIZE)


func to_dict() -> Dictionary:
	return {
		"grid_size": grid_size,
		"symbols": symbols,
		"countdown": countdown,
		"fixation_dot": fixation_dot,
		"show_next_target": show_next_target,
		"dim_found": dim_found,
		"show_errors": show_errors,
		"highlight_correct": highlight_correct,
		"show_timer": show_timer,
		"reverse": reverse,
		"shuffle_after_click": shuffle_after_click,
		"red_black": red_black,
		"test_mode": test_mode,
	}
