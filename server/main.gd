extends SceneTree
## D-338 (M9.5): điểm chạy máy chủ phòng trên VPS (systemd clashborn-rooms, xem docs/VPS_SETUP.md):
##   godot --headless --path <repo> -s server/main.gd -- [--port=8790] [--api=http://127.0.0.1:8787] [--dev-auth]
## --dev-auth (chỉ thử ở máy mình): token "name:<tên>" là tài khoản giả — KHÔNG dùng trên VPS.

var _server: RoomServer


func _initialize() -> void:
	var port: int = 8790
	var api: String = "http://127.0.0.1:8787"
	var dev: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			port = int(a.trim_prefix("--port="))
		elif a.begins_with("--api="):
			api = a.trim_prefix("--api=")
		elif a == "--dev-auth":
			dev = true
	_server = RoomServer.new()
	root.add_child(_server)
	if dev:
		_server.auth = ApiAuth.dev
	else:
		var a: ApiAuth = ApiAuth.new()
		a.api = api
		_server.add_child(a)
		_server.auth = a.check
	var err: Error = _server.start(port)
	print("room_server: %s cổng %d, dấu vân tay SIM %s, %s" % ["nghe" if err == OK else "LỖI %d" % err, port,
		_server.fingerprint, "tài khoản giả (dev)" if dev else "tài khoản qua " + api])
	if err != OK:
		quit(1)
