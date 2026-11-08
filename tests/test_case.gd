class_name TestCase
extends Node
## Minimal base class for headless unit tests. Methods named test_* are run
## by tests/run_tests.gd. Each test gets a fresh instance added to the tree.

var _failures: Array[String] = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		_failures.append("expected true. " + msg)


func assert_false(cond: bool, msg: String = "") -> void:
	if cond:
		_failures.append("expected false. " + msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if actual != expected:
		_failures.append("expected %s, got %s. %s" % [str(expected), str(actual), msg])


func assert_almost(actual: float, expected: float, eps: float = 0.0001, msg: String = "") -> void:
	if absf(actual - expected) > eps:
		_failures.append("expected ~%f, got %f. %s" % [expected, actual, msg])


func assert_null(value: Variant, msg: String = "") -> void:
	if value != null:
		_failures.append("expected null, got %s. %s" % [str(value), msg])


func get_failures() -> Array[String]:
	return _failures
