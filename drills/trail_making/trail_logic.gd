## Trail Making: connect scattered nodes in order. Part A: numbers only,
## ascending or descending. Part B: numbers and letters alternating, where the
## two series can run in the same or opposite directions.
class_name TrailLogic
extends RefCounted

enum Order { NUMBERS_ASC, NUMBERS_DESC, NUMBERS_ASC_LETTERS_DESC, NUMBERS_DESC_LETTERS_ASC }

const LETTERS := "ABCDEFGHIJKLM"
const MIN_DISTANCE := 0.17
const PLACEMENT_ATTEMPTS := 400
const MARGIN := 0.06

var count: int
var order: Order
## True for the alternating number/letter variants.
var part_b: bool
var labels: Array[String] = []
## Node centres in board-relative coordinates.
var positions: Array[Vector2] = []
var next_index: int = 0
var error_count: int = 0
var found_at_ms: Array[int] = []
var finished: bool = false


func _init(p_count: int, p_order: Order, rng: RandomNumberGenerator) -> void:
	count = p_count
	order = p_order
	part_b = order == Order.NUMBERS_ASC_LETTERS_DESC or order == Order.NUMBERS_DESC_LETTERS_ASC
	labels = build_labels(count, order)
	positions = _scatter(count, rng)


## The sequence of labels for [param n] nodes in the given order.
static func build_labels(n: int, p_order: Order) -> Array[String]:
	var out: Array[String] = []
	if p_order == Order.NUMBERS_ASC or p_order == Order.NUMBERS_DESC:
		for i in n:
			out.append(str(i + 1 if p_order == Order.NUMBERS_ASC else n - i))
		return out
	var number_count := (n + 1) / 2
	var letter_count := n / 2
	var numbers_ascending := p_order == Order.NUMBERS_ASC_LETTERS_DESC
	for i in n:
		if i % 2 == 0:
			var k := i / 2
			out.append(str(k + 1 if numbers_ascending else number_count - k))
		else:
			var k := i / 2
			out.append(LETTERS[k] if not numbers_ascending else LETTERS[letter_count - 1 - k])
	return out


## Rejection sampling with a shrinking distance so placement always terminates.
func _scatter(n: int, rng: RandomNumberGenerator) -> Array[Vector2]:
	var placed: Array[Vector2] = []
	var min_distance := MIN_DISTANCE
	while placed.size() < n:
		var ok := false
		for attempt in PLACEMENT_ATTEMPTS:
			var candidate := Vector2(rng.randf_range(MARGIN, 1.0 - MARGIN), rng.randf_range(MARGIN, 1.0 - MARGIN))
			var clear := true
			for other in placed:
				if other.distance_to(candidate) < min_distance:
					clear = false
					break
			if clear:
				placed.append(candidate)
				ok = true
				break
		if not ok:
			min_distance *= 0.85
	return placed


## Returns true when [param index] was the next node in order.
func register_click(index: int, elapsed_ms: int) -> bool:
	if finished:
		return false
	if index != next_index:
		error_count += 1
		return false
	found_at_ms.append(elapsed_ms)
	next_index += 1
	if next_index >= count:
		finished = true
	return true


static func order_key(p_order: Order) -> String:
	match p_order:
		Order.NUMBERS_DESC:
			return "TRAIL_ORDER_NUM_DESC"
		Order.NUMBERS_ASC_LETTERS_DESC:
			return "TRAIL_ORDER_NUM_ASC_LET_DESC"
		Order.NUMBERS_DESC_LETTERS_ASC:
			return "TRAIL_ORDER_NUM_DESC_LET_ASC"
	return "TRAIL_ORDER_NUM_ASC"


func total_time_ms() -> int:
	return found_at_ms[found_at_ms.size() - 1] if not found_at_ms.is_empty() else 0


func build_result(drill_id: StringName, config: Dictionary) -> DrillResult:
	var result := DrillResult.new()
	result.drill_id = drill_id
	result.config = config
	result.total_ms = total_time_ms()
	result.error_count = error_count
	result.finished_at_unix = int(Time.get_unix_time_from_system())
	result.summary_rows = [
		PackedStringArray(["RESULT_PART", order_key(order)]),
		PackedStringArray(["RESULT_TIME", Format.seconds(total_time_ms())]),
		PackedStringArray(["RESULT_ERRORS", str(error_count)]),
		PackedStringArray(["RESULT_AVERAGE_PER_NUMBER", Format.seconds(roundi(float(total_time_ms()) / count))]),
	]
	result.details = {"found_at_ms": found_at_ms.duplicate(), "order": order}
	result.metrics = {"total_ms": float(total_time_ms()), "errors": float(error_count)}
	return result
