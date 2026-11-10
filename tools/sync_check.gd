extends SceneTree
## M9.3 (D-336): chạy SyncCheck không giao diện, ghi kết quả JSON (so với điện thoại bằng tools/sync_compare.py).
## godot --headless --path . -s tools/sync_check.gd -- out.json [--seconds=300]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seconds: int = SyncCheck.SECONDS
	for a: String in args:
		if a.begins_with("--seconds="):
			seconds = int(a.trim_prefix("--seconds="))
	var s: SyncCheck = SyncCheck.new(seconds)
	var t0: int = Time.get_ticks_msec()
	while not s.done():
		s.advance(300)
	var f: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(s.result({"device": OS.get_name() + " " + Engine.get_architecture_name(),
		"version": Updater.current_name(), "ms": Time.get_ticks_msec() - t0})))
	f.close()
	print("sync_check: %d giây, %d ms, mã cuối %s" % [s.seconds.size(), Time.get_ticks_msec() - t0, s.seconds[-1]["hash"].left(16)])
	quit(0)
