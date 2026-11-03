## Minimal test base: methods named test_* are run by the runner.
class_name TestCase
extends RefCounted

var failures: Array[String] = []
var current := ""


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg])


func eq(a: Variant, b: Variant, msg := "") -> void:
	if a != b:
		failures.append("%s: expected %s, got %s %s" % [current, str(b), str(a), msg])


func near(a: float, b: float, eps: float, msg := "") -> void:
	if absf(a - b) > eps:
		failures.append("%s: expected ~%s, got %s %s" % [current, str(b), str(a), msg])
