extends SceneTree
## D-338 (M9.5): điểm chạy máy chủ phòng trên VPS (systemd clashborn-rooms, xem docs/VPS_SETUP.md):
##   godot --headless --path <repo> -s server/main.gd -- --server-id=<1–9> [--port=8790] [--api=http://127.0.0.1:8787] [--dev-auth]
## --server-id (bắt buộc, D-401 NET-15): id máy này trong app/net/room_servers.json — chữ số đầu mọi mã phòng nó phát.
## --dev-auth (chỉ thử ở máy mình): token "name:<tên>" là tài khoản giả — KHÔNG dùng trên VPS.

var _server: RoomServer


func _initialize() -> void:
	var port: int = 8790
	var api: String = "http://127.0.0.1:8787"
	var dev: bool = false
	var server_id: int = 0
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--server-id="):
			server_id = int(a.trim_prefix("--server-id="))
		elif a.begins_with("--port="):
			port = int(a.trim_prefix("--port="))
		elif a.begins_with("--api="):
			api = a.trim_prefix("--api=")
		elif a == "--dev-auth":
			dev = true
	if RoomServers.by_id(RoomServers.load_list(), server_id).is_empty():
		print("room_server: LỖI --server-id=%d không có trong app/net/room_servers.json" % server_id)
		quit(1)
		return
	Engine.max_fps = 240  # D-345: vòng ~4 ms — đủ mịn cho nhịp 30 tick / giây, không quay hết một nhân CPU của VPS
	_server = RoomServer.new()
	_server.server_id = server_id
	root.add_child(_server)
	if dev:
		_server.auth = ApiAuth.dev
	else:
		var a: ApiAuth = ApiAuth.new()
		a.api = api
		_server.add_child(a)
		_server.auth = a.check
	var err: Error = _server.start(port)
	print("room_server: %s cổng %d, máy %d, dấu vân tay SIM %s, %s" % ["nghe" if err == OK else "LỖI %d" % err, port,
		server_id, _server.fingerprint, "tài khoản giả (dev)" if dev else "tài khoản qua " + api])
	if err != OK:
		quit(1)
