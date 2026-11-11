class_name RoomServer
extends Node
## D-338 (M9.5): máy chủ phòng online — nhận WebSocket (nginx: wss://clashborn.quest/play → 127.0.0.1:PORT), bắt tay (dấu
## vân tay SIM NET-10 + phiên tài khoản NET-06), sảnh (RoomLobby, NET-07..09), vào trận → LockstepRoom giữ nhịp 30 tick
## mỗi giây (NET-01..04). Chạy: server/main.gd. Tin nhắn (máy khách → máy chủ): hello {v, token}; create {size};
## join {code}; team {team}; pick {hero}; size {size}; start; leave. Máy chủ → máy khách: hello_ok {peer, name, heroes};
## lobby {room}; error {code, for}; welcome {config, peer, slot, entity, delay}; rồi tin lockstep (tick, pong, desync); end.

const HELLO_TIMEOUT_S: float = 10.0
const CLOSE_AFTER_S: float = 0.5  ## đóng sau khi báo lỗi — để tin lỗi kịp đi
const MAX_CONNECTIONS: int = 200
const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"

## Kiểm phiên: func(token: String, done: Callable) — done({id, name}) hoặc done({}) khi phiên sai / bị khóa.
var auth: Callable
var fingerprint: String = ""
var heroes: Array[StringName] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _tcp: TCPServer = TCPServer.new()
var _lib: ContentLibrary
var _next: int = 1
var _conns: Dictionary[int, Dictionary] = {}    ## mã → {ws, stage (hello / auth / lobby / game), account, name, code, age}
var _lobbies: Dictionary[String, RoomLobby] = {}
var _games: Dictionary[String, Dictionary] = {}  ## mã phòng → {room, acc}


func start(port: int) -> Error:
	_lib = ContentLibrary.load_dir()
	for id: StringName in _lib.heroes:
		heroes.append(id)
	heroes.sort()
	fingerprint = NetVersion.fingerprint()
	rng.randomize()  # máy chủ chọn seed trận (NET-08) — tầng APP, không phải SIM
	return _tcp.listen(port, "127.0.0.1")


func stop() -> void:
	for id: int in _conns:
		(_conns[id]["ws"] as WsTransport).close()
	_tcp.stop()


func _process(delta: float) -> void:
	tick(delta)


## Một vòng (máy chủ thật: mỗi khung; test: gọi tay).
func tick(delta: float) -> void:
	_accept()
	for id: int in _conns.keys():
		_poll(id, delta)
	for code: String in _games.keys():
		_run_game(code, delta)


func _accept() -> void:
	while _tcp.is_connection_available():
		var stream: StreamPeerTCP = _tcp.take_connection()
		if _conns.size() >= MAX_CONNECTIONS:
			stream.disconnect_from_host()
			continue
		stream.set_no_delay(true)  # D-345: tắt Nagle — gói lệnh mỗi tick đi ngay, không bị gom chờ
		var ws: WebSocketPeer = WebSocketPeer.new()
		ws.accept_stream(stream)
		_conns[_next] = {"ws": WsTransport.wrap(ws), "stage": "hello", "account": -1, "name": "", "code": "", "age": 0.0}
		_next += 1


func _poll(id: int, delta: float) -> void:
	var c: Dictionary = _conns[id]
	var ws: WsTransport = c["ws"]
	if c["stage"] == "game":
		ws.peer.poll()  # tin trong trận do LockstepRoom đọc
	else:
		for msg: Dictionary in ws.receive():
			_handle(id, msg)
	c["age"] = float(c["age"]) + delta
	if (c["stage"] == "hello" and float(c["age"]) > HELLO_TIMEOUT_S) or float(c.get("close_at", INF)) <= float(c["age"]):
		ws.close()
	if ws.closed():
		_drop(id)


func _send(id: int, msg: Dictionary) -> void:
	if _conns.has(id):
		(_conns[id]["ws"] as WsTransport).send(msg)


func _close_soon(id: int) -> void:
	_conns[id]["stage"] = "closing"
	_conns[id]["close_at"] = float(_conns[id]["age"]) + CLOSE_AFTER_S


func _error(id: int, code: String, about: String) -> void:
	_send(id, {"t": "error", "code": code, "for": about})


func _handle(id: int, msg: Dictionary) -> void:
	var t: String = String(msg.get("t", ""))
	match String(_conns[id]["stage"]):
		"hello":
			if t != "hello":
				return
			if String(msg.get("v", "")) != fingerprint:  # NET-10
				_error(id, "VERSION", "hello")
				_close_soon(id)
				return
			_conns[id]["stage"] = "auth"
			auth.call(String(msg.get("token", "")), func(account: Dictionary) -> void: _authed(id, account))
		"lobby":
			_lobby_message(id, t, msg)


func _authed(id: int, account: Dictionary) -> void:
	if not _conns.has(id):
		return
	if account.is_empty() or String(account.get("name", "")) == "":  # NET-06: phải đăng nhập + có tên trong game
		_error(id, "AUTH" if account.is_empty() else "NO_NAME", "hello")
		_close_soon(id)
		return
	_conns[id].merge({"stage": "lobby", "account": int(account["id"]), "name": String(account["name"])}, true)
	_send(id, {"t": "hello_ok", "peer": id, "name": account["name"], "heroes": heroes.map(func(h: StringName) -> String: return String(h))})


func _lobby_message(id: int, t: String, msg: Dictionary) -> void:
	if t == "create" or t == "join":
		var e: String = _create_or_join(id, t, msg)
		if e != "":
			_error(id, e, t)
		else:
			_broadcast_lobby(_lobbies[String(_conns[id]["code"])])
		return
	if t == "leave":
		_leave(id)
		return
	var lobby: RoomLobby = _lobbies.get(String(_conns[id]["code"]))
	if lobby == null:
		if t in ["team", "pick", "size", "start"]:
			_error(id, "NO_ROOM", t)
		return
	var err: String = ""
	match t:
		"team":
			err = lobby.choose_team(id, int(msg.get("team", 0)))
		"pick":
			err = lobby.pick(id, StringName(String(msg.get("hero", ""))), heroes)
		"size":
			err = lobby.set_size(id, int(msg.get("size", 3)))
		"start":
			err = lobby.can_start(id)
			if err == "":
				_start_game(lobby)
				return
		_:
			return
	if err != "":
		_error(id, err, t)
	else:
		_broadcast_lobby(lobby)


## create {size} / join {code} — "" khi đã vào phòng.
func _create_or_join(id: int, t: String, msg: Dictionary) -> String:
	if _lobbies.has(String(_conns[id]["code"])):
		return "IN_ROOM"
	if t == "create":
		var lobby: RoomLobby = RoomLobby.new(_new_code(), int(msg.get("size", 3)))
		_lobbies[lobby.code] = lobby
		return _enter(id, lobby)
	var found: RoomLobby = _lobbies.get(String(msg.get("code", "")).to_upper().strip_edges())
	return "NO_ROOM" if found == null else _enter(id, found)


func _new_code() -> String:
	var code: String = RoomLobby.new_code(rng)
	while _lobbies.has(code) or _games.has(code):
		code = RoomLobby.new_code(rng)
	return code


func _enter(id: int, lobby: RoomLobby) -> String:
	var err: String = lobby.join(id, int(_conns[id]["account"]), String(_conns[id]["name"]))
	if err == "":
		_conns[id]["code"] = lobby.code
	elif lobby.empty():
		_lobbies.erase(lobby.code)
	return err


func _leave(id: int) -> void:
	var code: String = String(_conns[id]["code"])
	var lobby: RoomLobby = _lobbies.get(code)
	_conns[id]["code"] = ""
	if lobby == null:
		return
	lobby.leave(id)
	if lobby.empty():
		_lobbies.erase(code)
	else:
		_broadcast_lobby(lobby)
	_send(id, {"t": "lobby", "room": {}})


func _broadcast_lobby(lobby: RoomLobby) -> void:
	for m: int in lobby.members:
		_send(m, {"t": "lobby", "room": lobby.state()})


## NET-08: dựng trận (bản SIM của máy chủ), gắn từng người với hero của ô mình, gửi lời chào; từ đây LockstepRoom giữ nhịp.
func _start_game(lobby: RoomLobby) -> void:
	var made: Dictionary = lobby.build(heroes, rng)
	var cfg: MatchConfig = made["config"]
	var world: World = World.new(cfg.seed, load(BALANCE_PATH) as BalanceSettings)
	world.map = load(MAP_PATH) as MapLayout
	world.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	var units: Array[Entity] = MatchSetup.build(world, _lib, cfg)
	var room: LockstepRoom = LockstepRoom.new(world)
	var wire: Dictionary = NetCodec.config_to(cfg)
	for peer: int in made["seats"]:
		var slot: int = int(made["seats"][peer])
		room.add_peer(peer, _conns[peer]["ws"], units[slot].id)
		_conns[peer]["stage"] = "game"
		_send(peer, {"t": "welcome", "config": wire, "peer": peer, "slot": slot, "entity": units[slot].id,
			"delay": room.input_delay})
	_lobbies.erase(lobby.code)
	_games[lobby.code] = {"room": room, "acc": 0.0}


func _run_game(code: String, delta: float) -> void:
	var g: Dictionary = _games[code]
	var room: LockstepRoom = g["room"]
	room.pump()
	g["acc"] = float(g["acc"]) + delta
	var steps: int = 0
	while float(g["acc"]) >= SimClock.TICK_SECONDS and steps < LockstepClient.MAX_STEPS_PER_FRAME:
		g["acc"] = float(g["acc"]) - SimClock.TICK_SECONDS
		room.step_tick()
		steps += 1
	if room.world.winner >= 0 or room.peers.is_empty():
		for id: int in room.peers:
			_send(id, {"t": "end", "winner": room.world.winner})
			_conns[id].merge({"stage": "lobby", "code": ""}, true)
		_games.erase(code)


func _drop(id: int) -> void:
	var code: String = String(_conns[id]["code"])
	if _lobbies.has(code):
		_leave(id)
	if _games.has(code):
		(_games[code]["room"] as LockstepRoom).remove_peer(id)
	_conns.erase(id)
