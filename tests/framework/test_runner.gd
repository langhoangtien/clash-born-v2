class_name TestRunner
extends RefCounted
## Tìm và chạy test. File test: tests/**/test_*.gd, trừ thư mục fixtures/.

const SKIP_DIRS: PackedStringArray = ["fixtures", "framework"]

static var _capture: ErrorCapture = null

var verbose: bool = false


func discover(root: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	_walk(root, found)
	found.sort()
	return found


func run_files(paths: PackedStringArray, name_filter: String = "") -> TestReport:
	_ensure_capture()
	var report: TestReport = TestReport.new()
	for path: String in paths:
		_run_file(path, name_filter, report)
	return report


func _walk(dir_path: String, found: PackedStringArray) -> void:
	for sub: String in DirAccess.get_directories_at(dir_path):
		if not SKIP_DIRS.has(sub) and not sub.begins_with("."):
			_walk(dir_path.path_join(sub), found)
	for file: String in DirAccess.get_files_at(dir_path):
		if file.begins_with("test_") and file.ends_with(".gd"):
			found.append(dir_path.path_join(file))


func _run_file(path: String, name_filter: String, report: TestReport) -> void:
	report.files += 1
	var script: GDScript = load(path) as GDScript
	if script == null or not script.can_instantiate():
		report.add_failure(path, PackedStringArray(["không nạp được script"]))
		return
	for method: Dictionary in script.get_script_method_list():
		var test_name: String = method["name"]
		if not test_name.begins_with("test_"):
			continue
		if not name_filter.is_empty() and not (path + ":" + test_name).contains(name_filter):
			continue
		_run_one(script, path, test_name, report)


func _run_one(script: GDScript, path: String, test_name: String, report: TestReport) -> void:
	var instance: Object = script.new()
	if not instance is TestCase:
		report.add_failure(path, PackedStringArray(["file test phải extends TestCase"]))
		return
	var test: TestCase = instance as TestCase
	_capture.begin()
	if test.has_method("before_each"):
		test.call("before_each")
	test.call(test_name)
	if test.has_method("after_each"):
		test.call("after_each")
	var reasons: PackedStringArray = test.take_failures()
	reasons.append_array(_capture.end())
	var full_name: String = "%s:%s" % [path.get_file().get_basename(), test_name]
	if reasons.is_empty():
		report.passed += 1
		if verbose:
			print("  ok   ", full_name)
	else:
		report.add_failure(full_name, reasons)
		if verbose:
			print("  FAIL ", full_name)


static func _ensure_capture() -> void:
	if _capture == null:
		_capture = ErrorCapture.new()
		OS.add_logger(_capture)
