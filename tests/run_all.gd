extends SceneTree
## Chạy mọi test: godot --headless --path . -s res://tests/run_all.gd [-- --filter=CRP_05 --verbose]
## Mã thoát: 0 = xanh, 1 = có test đỏ, 2 = không có test nào chạy.


func _initialize() -> void:
	# Chạy sau khi cây cảnh sẵn sàng: trong _initialize, root chưa ở trong cây nên
	# node thêm vào không nhận _ready (test cảnh của VIEW cần điều đó).
	_run.call_deferred()


func _run() -> void:
	var name_filter: String = ""
	var runner: TestRunner = TestRunner.new()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			name_filter = arg.trim_prefix("--filter=")
		elif arg == "--verbose":
			runner.verbose = true
	var report: TestReport = runner.run_files(runner.discover("res://tests"), name_filter)
	_print_report(report)
	if report.passed + report.failed == 0:
		quit(2)
	else:
		quit(0 if report.is_green() else 1)


func _print_report(report: TestReport) -> void:
	print("")
	for line: String in report.failure_lines:
		print("FAIL ", line)
	var status: String = "XANH" if report.is_green() else "ĐỎ"
	if report.passed + report.failed == 0:
		status = "KHÔNG CÓ TEST NÀO CHẠY"
	print("== %s: %d xanh, %d đỏ, %d file ==" % [status, report.passed, report.failed, report.files])
