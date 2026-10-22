class_name TestCase
extends RefCounted
## Lớp cha của mọi file test. Mỗi hàm bắt đầu bằng `test_` là một test.
## Tên test chứa mã luật khi kiểm tra một luật: test_CRP_05_creep_stops_before_next_tower.
## Có thể khai báo before_each() / after_each() để dựng và dọn trước/sau mỗi test.

var _failures: PackedStringArray = PackedStringArray()


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_record("expected true", message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		_record("expected false", message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not _same(actual, expected):
		_record("expected %s, got %s" % [_show(expected), _show(actual)], message)


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if _same(actual, unexpected):
		_record("expected anything but %s" % _show(unexpected), message)


func assert_near(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		_record("expected %s ± %s, got %s" % [expected, tolerance, actual], message)


func fail(message: String) -> void:
	_record("fail", message)


func take_failures() -> PackedStringArray:
	var out: PackedStringArray = _failures
	_failures = PackedStringArray()
	return out


func _record(reason: String, message: String) -> void:
	_failures.append(reason if message.is_empty() else "%s — %s" % [reason, message])


func _same(a: Variant, b: Variant) -> bool:
	# So kiểu trước để 1 và 1.0, "1" và &"1" không bị coi là bằng nhau ngầm.
	if typeof(a) != typeof(b):
		return false
	return a == b


func _show(value: Variant) -> String:
	if value is String:
		return "\"%s\"" % value
	return "%s(%s)" % [type_string(typeof(value)), str(value)]


## Balance cho test số kỹ năng theo bảng thiết kế: tắt khuếch đại phép từ Trí tuệ (CMB-13 có
## test riêng), để sát thương đúng số ghi trong CONTENT.md.
func balance_without_spell_amp(path: String) -> BalanceSettings:
	var b: BalanceSettings = (load(path) as BalanceSettings).duplicate()
	b.spell_amp_per_intelligence = 0.0
	return b
