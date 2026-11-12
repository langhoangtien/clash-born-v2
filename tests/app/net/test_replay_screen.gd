extends TestCase
## NET-22 (D-411): màn trận thật, phiên online giả đang tua vào lại — lúc tua cảnh trận bị che và dừng (chỉ còn chữ tiến độ
## + nút Cài đặt); tua xong mọi nút về đúng trạng thái trước khi che, hình đơn vị theo đúng World hiện tại (không nội suy từ
## vị trí cũ, không có xác giả của đơn vị chết lúc tua).

const SCENE: String = "res://app/match_scene.tscn"
const TICKS: int = 900


func _session() -> OnlineSession:
	var cfg: MatchConfig = MatchConfig.make(1, [&"gorran", &"myra"] as Array[StringName], [0, 1], BotState.Difficulty.NORMAL, 31)
	var s: OnlineSession = OnlineSession.new(NetTransport.new(), "", "")
	s.config = cfg
	s.stage = "game"
	var probe: World = World.new(cfg.seed, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	probe.map = load("res://data/maps/clashborn.tres") as MapLayout
	var heroes: Array = MatchSetup.build(probe, ContentLibrary.load_dir(), cfg).filter(
		func(e: Entity) -> bool: return e.kind == Entity.Kind.HERO)
	s.entity_id = heroes[1].id
	s.lockstep = LockstepClient.new(s.transport)
	s.lockstep.peer_id = 1
	s.lockstep.handle({"t": "history", "from": 1, "to": TICKS, "c": []})
	s.lockstep.resume_to = TICKS
	return s


func test_NET_22_scene_covered_while_replaying_and_restored_after() -> void:
	var script: Variant = load("res://app/match_scene.gd")
	var s: OnlineSession = _session()
	script.online = s
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	scene.set_process(false)
	scene.loading = null  # bỏ làm nóng shader (D-260) trong test
	var hud: Node = scene.get_node("Hud")
	var before: Dictionary = {}
	for n: Node in hud.get_children() + [scene.view_3d, scene.units_view, scene.map_view] as Array[Node]:
		before[n] = [n.get("visible"), n.process_mode]
	var replay: ReplayScreen = scene.replay
	scene.tick_frame(1.0 / 60.0)
	assert_true(replay.visible, "đang tua → che")
	assert_false(scene.view_3d.visible, "cảnh 3D ẩn")
	assert_eq(scene.view_3d.process_mode, Node.PROCESS_MODE_DISABLED, "cảnh 3D dừng")
	assert_false(scene.match_hud.visible, "HUD trận ẩn")
	assert_true(hud.get_node("OnlineStatus").visible, "chữ tiến độ vẫn hiện")
	assert_true(scene.settings.panel.visible, "nút Cài đặt vẫn hiện (thoát giữa lúc tua)")
	s.lockstep.catch_up_ms = 1000.0
	for i: int in 200:
		if s.lockstep.resume_to < 0:
			break
		scene.tick_frame(1.0 / 60.0)
	assert_eq(s.lockstep.resume_to, -1, "tua xong")
	scene.tick_frame(1.0 / 60.0)
	assert_false(replay.visible, "bỏ che")
	for n: Node in before:
		assert_eq([n.get("visible"), n.process_mode], before[n], "%s về như trước khi che" % n.name)
	var w: World = scene.world
	assert_true(w.tick >= TICKS)
	for e: Entity in w.entities:
		assert_eq(scene.units_view.display_position(e), e.position, "không nội suy từ vị trí cũ (đơn vị %d)" % e.id)
	for id: int in scene.view_3d._actors:
		var e: Entity = w.find_entity(id)
		assert_true(e != null and e.alive, "hình 3D chỉ cho đơn vị còn sống (%d)" % id)
	assert_eq(scene.view_3d._corpses.count(), 0, "không có xác giả của đơn vị chết lúc tua")
	assert_true(scene.view_3d._actors.has(scene.hero.id), "có hình hero của mình")
	scene.free()
	script.online = null
