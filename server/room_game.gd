class_name RoomGame
extends RefCounted
## Một trận đang chạy ở máy chủ phòng (D-338, tách khỏi RoomServer ở D-406): LockstepRoom giữ nhịp, cấu hình, ô → tài khoản
## / đơn vị (NET-12 biên bản, M9.8 vào lại), mã người chơi → ô, số bản người tạo phòng; trận trống (NET-19).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"

var code: String
var room: LockstepRoom
var cfg: MatchConfig
var accounts: Dictionary = {}   ## ô → tài khoản (mọi ô người lúc bắt đầu)
var entities: Dictionary = {}   ## ô → đơn vị
var slots: Dictionary = {}      ## mã người chơi (cả kết nối cũ đã rớt) → ô
var app: String = ""
var names: Dictionary = {}      ## mã người chơi → tên trong game (thông báo, nhật ký)
## func(peer) — máy chủ đóng kết nối của người bị coi là rớt khi kết nối còn mở (im lặng / lệch / bị thay).
var close_peer: Callable = Callable()
var _acc: float = 0.0
var _empty: float = 0.0


func _init(game_code: String, r: LockstepRoom, c: MatchConfig) -> void:
	code = game_code
	room = r
	cfg = c
	room.on_drop = _on_drop
	room.on_return = _on_return
	room.takeover = Command.set_control  # NET-17: bot Thường đánh thay người rớt (CMD-07)


## NET-08: dựng trận (bản SIM của máy chủ) theo cấu hình phòng; đơn vị của từng ô.
static func create(game_code: String, c: MatchConfig, lib: ContentLibrary) -> RoomGame:
	var world: World = World.new(c.seed, load(BALANCE_PATH) as BalanceSettings)
	world.map = load(MAP_PATH) as MapLayout
	world.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	var units: Array[Entity] = MatchSetup.build(world, lib, c)
	var g: RoomGame = RoomGame.new(game_code, LockstepRoom.new(world), c)
	for i: int in units.size():
		g.entities[i] = units[i].id
	return g


## Người chơi `peer` (tài khoản, tên) cầm ô `slot` từ đầu trận.
func seat(peer: int, t: NetTransport, slot: int, account: int, name: String) -> void:
	accounts[slot] = account
	slots[peer] = slot
	names[peer] = name
	room.add_peer(peer, t, entities[slot])


## Lời chào vào trận (NET-08); vào lại (NET-22) kèm resume + tick hiện tại.
func welcome(peer: int, slot: int, resume: bool) -> Dictionary:
	return {"t": "welcome", "config": NetCodec.config_to(cfg), "peer": peer, "slot": slot, "entity": entities[slot],
		"delay": room.input_delay, "resume": resume, "tick": room.tick}


## NET-22 / NET-23: kết nối mới của ô `slot` vào lại — kết nối cũ còn ở trận thì coi là rớt (replaced); ô không còn "đã rời".
func rejoin(peer: int, t: NetTransport, slot: int, name: String) -> void:
	var old: int = peer_of(slot)
	if old >= 0:
		room.drop_peer(old, "replaced")
	for p: int in slots.keys():
		if int(slots[p]) == slot:
			room.gone.erase(p)
	slots[peer] = slot
	names[peer] = name
	room.rejoin_peer(peer, t, entities[slot])


## NET-16 / NET-20 / NET-23: báo người còn lại, ghi nhật ký; kết nối còn mở thì đóng.
func _on_drop(peer: int, _entity: int, reason: String) -> void:
	print("room_server: phòng %s — %s (ô %d) rớt: %s, tick %d" % [code, names.get(peer, "?"), int(slots.get(peer, -1)), reason,
		room.tick])
	_notify("dropped", peer)
	if reason != "closed" and close_peer.is_valid():
		close_peer.call(peer)


## NET-18: người vào lại đã kịp.
func _on_return(peer: int) -> void:
	print("room_server: phòng %s — %s vào lại, tick %d" % [code, names.get(peer, "?"), room.tick])
	_notify("back", peer)


func _notify(kind: String, who: int) -> void:
	for id: int in room.peers:
		if id != who:
			room.peers[id].send({"t": "notice", "kind": kind, "name": String(names.get(who, "?"))})


## Một vòng của máy chủ: đọc tin, chạy tick theo thời gian (NET-01). Trả "won" / "cancel" (NET-19) / "".
func advance(delta: float, empty_keep_s: float) -> String:
	room.pump()
	_acc += delta
	var steps: int = 0
	while _acc >= SimClock.TICK_SECONDS and steps < LockstepClient.MAX_STEPS_PER_FRAME:
		_acc -= SimClock.TICK_SECONDS
		room.step_tick()
		steps += 1
	_empty = _empty + delta if room.peers.is_empty() else 0.0
	if room.world.winner >= 0:
		return "won"
	return "cancel" if _empty >= empty_keep_s else ""


## NET-12: biên bản cho máy chủ thống kê.
func payload() -> Dictionary:
	return MatchReport.payload(room, cfg, code, accounts, slots, app)


## NET-21: ô của tài khoản trong trận (-1 = không có).
func slot_of(account: int) -> int:
	for slot: int in accounts:
		if int(accounts[slot]) == account:
			return slot
	return -1


## Mã người chơi đang nối của ô (-1 = không ai).
func peer_of(slot: int) -> int:
	for peer: int in room.peers:
		if int(slots.get(peer, -1)) == slot:
			return peer
	return -1
