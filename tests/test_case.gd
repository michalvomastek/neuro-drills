## Base class for headless tests. Assertions record failures instead of
## stopping, so one run reports everything that is wrong.
class_name TestCase
extends RefCounted

var _failures: PackedStringArray = PackedStringArray()


## Runs before every test method.
func before_each() -> void:
	pass


func begin_test() -> void:
	_failures.clear()


func end_test() -> PackedStringArray:
	return _failures.duplicate()


func fail(message: String) -> void:
	_failures.append(message)


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		fail("expected true" + _suffix(message))


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		fail("expected false" + _suffix(message))


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		fail("expected %s, got %s%s" % [expected, actual, _suffix(message)])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if actual == unexpected:
		fail("did not expect %s%s" % [unexpected, _suffix(message)])


func _suffix(message: String) -> String:
	return "" if message.is_empty() else " (%s)" % message
