extends TestCase
## NET-01..05 (D-337, M9.4): lockstep qua mạng giả — 2 người thật (mỗi đội một) + 4 bot, máy chủ giữ nhịp. Mọi bản SIM
## (2 máy khách + máy chủ) phải cùng mã băm ở mọi mốc; lệnh muộn sang tick kế; lệnh sai quyền bị bỏ; một máy rớt không
## làm trận dừng; máy lệch bị phát hiện.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const SIX: Array[StringName] = [&"brakk", &"myra", &"vexa", &"noctis", &"gorran", &"duy_anh"]
const FRAME: float = 1.0 / 60.0
const HUMANS: Array[int] = [0, 3]

static var _lib: ContentLibrary


func _world(cfg: MatchConfig) -> World:
	if _lib == null:
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(cfg.seed, load(BALANCE_PATH) as BalanceSettings)
	w.map = load(MAP_PATH) as MapLayout
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.build(w, _lib, cfg)
	return w


## {net, room, clients, heroes (id đơn vị của từng người)}.
func _setup(rtt: float, jitter: float, loss: float, seed_value: int = 7) -> Dictionary:
	var cfg: MatchConfig = MatchConfig.make(3, SIX, HUMANS, BotState.Difficulty.NORMAL, 31)
	var net: LoopbackNet = LoopbackNet.new(seed_value)
	var room: LockstepRoom = LockstepRoom.new(_world(cfg))
	var clients: Array[LockstepClient] = []
	var heroes: Array[int] = []
	for k: int in HUMANS.size():
		var w: World = _world(cfg)
		var hero: int = w.entities.filter(func(e: Entity) -> bool: return e.kind == Entity.Kind.HERO)[HUMANS[k]].id
		var ends: Array = net.link(rtt, jitter, loss)
		room.add_peer(k, ends[1], hero)
		var c: LockstepClient = LockstepClient.new(ends[0])
		c.attach(w, room.input_delay, k)
		clients.append(c)
		heroes.append(hero)
	return {"net": net, "room": room, "clients": clients, "heroes": heroes, "rng": RandomNumberGenerator.new()}


## Chạy `seconds` giây đồng hồ ảo: máy chủ đúng 30 tick / giây; máy khách chạy tick khi có gói (tối đa 5 / khung);
## người chơi ra lệnh ngẫu nhiên mỗi 0,25 giây (trừ máy đã rớt).
func _run(h: Dictionary, seconds: float, act: bool = true) -> void:
	var net: LoopbackNet = h["net"]
	var room: LockstepRoom = h["room"]
	var acc: float = 0.0
	var frames: int = int(seconds / FRAME)
	for f: int in frames:
		net.now += FRAME
		acc += FRAME
		room.pump()
		while acc >= SimClock.TICK_SECONDS:
			acc -= SimClock.TICK_SECONDS
			room.step_tick()
		for k: int in h["clients"].size():
			var c: LockstepClient = h["clients"][k]
			c.pump(net.now)
			c.advance(FRAME)
			if act and f % 15 == k and c.transport.is_open():
				_act(h, c, h["heroes"][k])


func _act(h: Dictionary, c: LockstepClient, hero: int) -> void:
	var rng: RandomNumberGenerator = h["rng"]
	var e: Entity = c.world.find_entity(hero)
	if e == null or not e.alive:
		return
	match rng.randi() % 3:
		0:
			c.world.submit(Command.move_to(hero, e.position + Vector2(rng.randf_range(-600, 600), rng.randf_range(-600, 600))))
		1:
			c.world.submit(Command.attack_auto(hero, 0))
		2:
			c.world.submit(Command.cast(hero, 1, -1, e.position + Vector2(rng.randf_range(-300, 300), rng.randf_range(-300, 300))))


## Mốc mã băm chung của mọi máy khách và máy chủ: phải giống hệt.
func _same_hashes(h: Dictionary) -> int:
	var room: LockstepRoom = h["room"]
	var checked: int = 0
	for n: int in room._hashes:
		for c: LockstepClient in h["clients"]:
			if c.hashes.has(n):
				assert_eq(c.hashes[n], room._hashes[n], "mốc tick %d" % n)
				checked += 1
	return checked


func test_NET_01_all_copies_same_hash_under_jitter_and_loss() -> void:
	var h: Dictionary = _setup(80.0, 30.0, 0.03)
	_run(h, 8.0)
	var room: LockstepRoom = h["room"]
	assert_eq(room.tick, 240, "máy chủ giữ nhịp 30 tick / giây")
	assert_true(_same_hashes(h) >= 10, "đã so đủ mốc")
	assert_eq(room.desyncs.size(), 0, "không máy nào lệch")
	var applied: int = h["clients"][0].world.command_log.filter(func(c: Command) -> bool: return c.entity_id in h["heroes"]).size()
	assert_true(applied > 20, "lệnh người chơi đi qua mạng và được áp (%d)" % applied)
	for c: LockstepClient in h["clients"]:
		assert_true(room.tick - c.world.tick <= 10, "máy khách theo kịp máy chủ")
		assert_true(c.rtt_ms > 60.0 and c.rtt_ms < 200.0, "đo được RTT (%.0f ms)" % c.rtt_ms)
		assert_true(c.input_latency_ms > 0.0, "đo được trễ bấm → hiệu lực")


func test_NET_02_local_command_goes_to_server_not_applied_locally() -> void:
	var h: Dictionary = _setup(50.0, 0.0, 0.0)
	_run(h, 1.0, false)
	var c: LockstepClient = h["clients"][0]
	var hero: int = h["heroes"][0]
	var before: int = c.world.command_log.size()
	c.world.submit(Command.move_to(hero, c.world.find_entity(hero).position + Vector2(300, 0)))
	assert_eq(c.world._pending.size(), 0, "lệnh người chơi không vào thẳng hàng chờ")
	_run(h, 0.5, false)
	var mine: Array = c.world.command_log.slice(before).filter(func(x: Command) -> bool: return x.entity_id == hero)
	assert_eq(mine.size(), 1, "lệnh quay về qua gói máy chủ rồi mới áp")
	var room_log: Array = h["room"].world.command_log.filter(func(x: Command) -> bool: return x.entity_id == hero)
	assert_eq(room_log.size(), 1)
	assert_eq(room_log[0].tick, mine[0].tick, "mọi máy áp cùng tick")


func test_NET_02_late_command_moves_to_next_tick() -> void:
	var h: Dictionary = _setup(50.0, 0.0, 0.0)
	_run(h, 1.0, false)
	var room: LockstepRoom = h["room"]
	var hero: int = h["heroes"][0]
	room._handle(0, {"t": "cmd", "want": 1, "s": 99, "c": NetCodec.command_to(Command.stop(hero))})
	var now: int = room.tick
	room.step_tick()
	var got: Array = room.world.command_log.filter(func(x: Command) -> bool: return x.entity_id == hero)
	assert_eq(got.size(), 1, "lệnh muộn không bị bỏ")
	assert_eq(got[0].tick, now + 1, "sang tick kế của máy chủ")


func test_NET_03_command_for_other_hero_dropped() -> void:
	var h: Dictionary = _setup(50.0, 0.0, 0.0)
	var room: LockstepRoom = h["room"]
	room._handle(0, {"t": "cmd", "want": 5, "s": 1, "c": NetCodec.command_to(Command.stop(h["heroes"][1]))})
	room._handle(0, {"t": "cmd", "want": 5, "s": 2, "c": {"k": 999}})
	room._handle(0, {"t": "cmd", "want": 5, "s": 3, "c": "rác"})
	assert_eq(room.dropped, 3, "sai quyền / sai dạng → bỏ")
	for i: int in LockstepRoom.MAX_COMMANDS_PER_S + 5:
		room._handle(0, {"t": "cmd", "want": 5, "s": 10 + i, "c": NetCodec.command_to(Command.stop(h["heroes"][0]))})
	assert_eq(room.dropped, 8, "quá %d lệnh / giây → bỏ phần thừa" % LockstepRoom.MAX_COMMANDS_PER_S)


func test_NET_01_one_client_drops_match_continues() -> void:
	var h: Dictionary = _setup(60.0, 10.0, 0.0)
	_run(h, 2.0)
	h["clients"][1].transport.close()
	_run(h, 3.0)
	var room: LockstepRoom = h["room"]
	var alive: LockstepClient = h["clients"][0]
	assert_eq(room.tick, 150, "máy chủ không chờ máy rớt")
	assert_true(room.tick - alive.world.tick <= 10, "máy còn lại vẫn chạy theo")
	assert_true(h["clients"][1].world.tick < 70, "máy rớt đứng lại")
	assert_eq(room.desyncs.size(), 0)


func test_NET_04_tampered_client_detected() -> void:
	var h: Dictionary = _setup(40.0, 0.0, 0.0)
	_run(h, 1.0)
	var c: LockstepClient = h["clients"][1]
	c.world.find_entity(h["heroes"][1]).gold += 10000  # máy bị sửa
	_run(h, 2.0)
	var room: LockstepRoom = h["room"]
	assert_true(room.desyncs.has(1), "máy chủ phát hiện máy lệch")
	assert_false(room.desyncs.has(0), "máy không sửa vẫn khớp")
	assert_true(c.desync_tick > 0, "máy lệch được báo tick lệch đầu tiên")


func test_NET_codec_round_trip_and_config() -> void:
	var c: Command = Command.cast(12, 2, 7, Vector2(1234.5, 99.25))
	c.lock = true
	var back: Command = NetCodec.command_from(JSON.parse_string(JSON.stringify(NetCodec.command_to(c))))
	assert_eq([back.type, back.entity_id, back.slot, back.target_id, back.point, back.lock], [c.type, 12, 2, 7, c.point, true])
	var cfg: MatchConfig = MatchConfig.make(3, SIX, HUMANS, BotState.Difficulty.HARD, 99)
	var cfg2: MatchConfig = NetCodec.config_from(JSON.parse_string(JSON.stringify(NetCodec.config_to(cfg))))
	assert_eq(NetCodec.config_to(cfg2), NetCodec.config_to(cfg))


## D-345: lệnh chiêu không có điểm nhắm (`point` = INF — chiêu chỉ hướng / chọn đơn vị / không nhắm) đi qua mạng nguyên vẹn.
## Trước: bộ mã coi INF là hỏng → máy chủ bỏ mọi lệnh tung chiêu (người chơi: "cả hai máy không dùng được skill").
func test_NET_02_cast_without_point_survives_wire() -> void:
	for c: Command in [Command.cast(7, AbilityDef.Slot.Q, -1, Vector2.INF, Vector2(0.6, -0.8)), Command.cast(7, AbilityDef.Slot.R),
			Command.cast(7, AbilityDef.Slot.W, 12)]:
		var back: Command = NetCodec.command_from(JSON.parse_string(JSON.stringify(NetCodec.command_to(c))))
		assert_true(back != null, "lệnh chiêu không bị bỏ")
		if back != null:
			assert_eq([back.type, back.slot, back.target_id, back.point, back.direction], [c.type, c.slot, c.target_id, c.point, c.direction])
	assert_true(NetCodec.command_from({"k": int(Command.Type.CAST), "e": 1, "p": [1e400, 0], "d": [0, 0], "t": -1, "l": false,
		"m": 0, "s": 0, "i": ""}) == null, "số hỏng thật vẫn bị bỏ")
