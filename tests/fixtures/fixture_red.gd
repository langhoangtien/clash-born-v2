extends TestCase
## Fixture CỐ Ý SAI cho test_framework.gd. Nằm trong tests/fixtures/ nên lệnh chạy
## test không tự chạy file này. Khi test_framework chạy nó, các dòng
## "SCRIPT ERROR" in ra là có chủ đích.


func test_correct() -> void:
	assert_eq(2 + 2, 4)


func test_wrong_equality() -> void:
	assert_eq(2 + 2, 5)


func test_script_error() -> void:
	print("  [cố ý] fixture_red gây lỗi script để kiểm tra khung test bắt được:")
	var missing: Object = null
	missing.call("does_not_exist")


func test_explicit_fail() -> void:
	fail("cố ý fail")
