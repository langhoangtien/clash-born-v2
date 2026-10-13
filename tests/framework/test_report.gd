class_name TestReport
extends RefCounted
## Kết quả một lần chạy test.

var passed: int = 0
var failed: int = 0
var files: int = 0
var failure_lines: PackedStringArray = PackedStringArray()


func is_green() -> bool:
	return failed == 0 and passed > 0


func add_failure(test_name: String, reasons: PackedStringArray) -> void:
	failed += 1
	for reason: String in reasons:
		failure_lines.append("%s: %s" % [test_name, reason])
