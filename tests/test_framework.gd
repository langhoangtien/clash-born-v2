extends TestCase
## Kiểm tra chính khung test (M0.2): test đúng phải xanh, test sai phải bị bắt đỏ.

const FAILING_FIXTURE: String = "res://tests/fixtures/fixture_red.gd"


func test_assertions_pass_on_correct_values() -> void:
	assert_true(1 + 1 == 2)
	assert_false(1 + 1 == 3)
	assert_eq(2 * 3, 6)
	assert_ne("a", "b")
	assert_near(0.1 + 0.2, 0.3, 0.000001)


func test_failing_fixture_is_reported_red() -> void:
	var report: TestReport = TestRunner.new().run_files([FAILING_FIXTURE])
	assert_eq(report.passed, 1, "fixture có đúng 1 test xanh")
	assert_eq(report.failed, 3, "fixture có 3 test đỏ: sai assert, lỗi script, fail()")
	assert_false(report.is_green(), "báo cáo có test đỏ thì không được xanh")


func test_fixture_failure_messages_name_the_test() -> void:
	var report: TestReport = TestRunner.new().run_files([FAILING_FIXTURE])
	var joined: String = "\n".join(report.failure_lines)
	assert_true(joined.contains("test_wrong_equality"), "báo lỗi phải có tên test")
	assert_true(joined.contains("expected int(5), got int(4)"), "báo lỗi phải có giá trị mong đợi")
	assert_true(joined.contains("test_script_error"), "lỗi script phải bị bắt thành test đỏ")


func test_discovery_skips_fixtures_folder() -> void:
	var files: PackedStringArray = TestRunner.new().discover("res://tests")
	for path: String in files:
		assert_false(path.contains("/fixtures/"), "không chạy fixture như test thật: " + path)
	assert_true(files.has("res://tests/test_framework.gd"))


func test_empty_report_is_not_green() -> void:
	var report: TestReport = TestRunner.new().run_files([])
	assert_false(report.is_green(), "không có test nào chạy thì không được coi là xanh")
