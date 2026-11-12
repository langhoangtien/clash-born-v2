class_name MatchSetup
extends RefCounted
## Dựng trận từ map + content: công trình, lính đường (controller + đợt lính).


static func spawn_structures(world: World, library: ContentLibrary) -> void:
	var map: MapLayout = world.map
	for i: int in range(map.tower_ids.size()):
		var def: UnitDef = library.units[StringName("tower_t%d" % map.tower_tiers[i])]
		var e: Entity = UnitFactory.unit(world, def, Entity.Kind.TOWER, map.tower_teams[i], map.tower_points[i])
		e.structure_id = StringName(map.tower_ids[i])
		e.tier = map.tower_tiers[i]
	for team: int in range(2):
		var core: Entity = UnitFactory.unit(world, library.units[&"core"], Entity.Kind.CORE, team, map.core_point(team))
		core.structure_id = StringName("core_%d" % team)
		core.tier = 5
	Objectives.refresh_locks(world)


## Gắn controller lính đường; `waves` = bật sinh đợt lính theo giờ (CRP-08).
static func add_lane_creeps(world: World, library: ContentLibrary, waves: bool) -> void:
	world.add_system(LaneCreepController.new(), World.Phase.CONTROLLER)
	if waves:
		world.add_system(WaveSpawner.new(library), World.Phase.SPAWN)
		# Dựng sẵn lưới tìm đường của lính lúc vào trận (~0.3 s), không để đợt lính đầu bị giật.
		for def: UnitDef in library.units.values():
			if def.kind in [UnitDef.Kind.CREEP_MELEE, UnitDef.Kind.CREEP_RANGED, UnitDef.Kind.CREEP_SIEGE]:
				world.navigation(def.stats.collision_radius)


static func spawn_creep(world: World, library: ContentLibrary, def_id: StringName, team: int, lane: String, at: Vector2) -> Entity:
	var def: UnitDef = library.units[def_id]
	var e: Entity = UnitFactory.unit(world, def, Entity.Kind.LANE_CREEP, team,
		world.navigation(def.stats.collision_radius).nearest_clear(at))
	e.lane = lane
	e.siege = def.kind == UnitDef.Kind.CREEP_SIEGE
	return e


## VIS-01: bật tầm nhìn cho trận (mọi trận thật; test cơ chế có thể bỏ qua để thấy hết).
static func add_vision(world: World) -> void:
	world.add_system(VisionSystem.new(), World.Phase.VISION)


## JGL: trại cho mọi loại trại trên map có CampDef (boss chưa có thì bỏ qua), controller và spawner.
static func add_jungle(world: World, library: ContentLibrary) -> void:
	var map: MapLayout = world.map
	for i: int in range(map.camp_ids.size()):
		var kind: StringName = StringName(map.camp_kinds[i])
		if not library.camps.has(kind):
			continue
		var c: CampState = CampState.new()
		c.index = i
		c.kind = kind
		c.center = map.camp_points[i]
		c.def = library.camps[kind]
		world.camps.append(c)
	for def: CampDef in library.camps.values():
		for u: UnitDef in def.units:
			world.navigation(u.stats.collision_radius)  # dựng sẵn, không giật lúc trại xuất hiện (D-70)
	world.add_system(JungleController.new(), World.Phase.CONTROLLER)
	world.add_system(JungleSpawner.new(), World.Phase.SPAWN)


## BOT: hero `e` do bot điều khiển (thêm BotController một lần cho trận).
## Trận đầy đủ theo cấu hình (MATCH-01..05): công trình, tầm nhìn, rừng, cửa hàng, lính đường, hero. World đã có map +
## MovementSystem. Dùng chung: màn trận, test, công cụ không giao diện (sim_profile, sim_matches).
static func build(world: World, library: ContentLibrary, config: MatchConfig) -> Array[Entity]:
	world.practice = config.practice  # MATCH-06
	spawn_structures(world, library)
	add_vision(world)
	add_jungle(world, library)
	add_shop(world, library)
	add_lane_creeps(world, library, true)
	return spawn_heroes(world, library, config)


## MATCH-01/03/04: tạo hero theo thứ tự ô — điểm xuất hiện riêng mỗi ô, ô bot nhận bộ não + đường. Cấu hình phải
## hợp lệ (MatchConfig.validate).
static func spawn_heroes(world: World, library: ContentLibrary, config: MatchConfig) -> Array[Entity]:
	var out: Array[Entity] = []
	for s: MatchSlot in config.slots:
		var def: HeroDef = library.heroes[s.hero_id]
		var at: Vector2 = spawn_point(world, s.team, s.index, config.team_size, def.stats.collision_radius)
		var e: Entity = UnitFactory.hero(world, def, s.team, at)
		e.spawn_point = at
		e.slot_index = s.index
		if s.is_bot:
			add_bot(world, e, s.difficulty).lane = lane_for(world, e)
		out.append(e)
	return out


## Đường của bot theo ô của hero (bot_lane_order).
static func lane_for(world: World, e: Entity) -> String:
	var order: PackedStringArray = world.balance.bot_lane_order
	return order[maxi(e.slot_index, 0) % order.size()]


## MATCH-03: ô 0 ở fountain; ô k ≥ 1 cách `hero_spawn_spread` theo góc chia đều, đẩy vào chỗ đứng được gần nhất.
static func spawn_point(world: World, team: int, index: int, team_size: int, radius: float) -> Vector2:
	var at: Vector2 = world.map.fountain_point(team)
	if index > 0:
		at += Vector2.from_angle(TAU * float(index - 1) / float(maxi(team_size - 1, 1))) * world.balance.hero_spawn_spread
	return world.navigation(radius).nearest_clear(at)


static func add_bot(world: World, e: Entity, difficulty: BotState.Difficulty = BotState.Difficulty.NORMAL) -> BotState:
	if not world.has_system(BotController):
		world.add_system(BotController.new(), World.Phase.CONTROLLER)
	e.bot = BotState.new()
	e.bot.difficulty = difficulty
	return e.bot


## SHOP (D-81): cửa hàng của trận là mọi món trong content.
static func add_shop(world: World, library: ContentLibrary) -> void:
	for id: StringName in library.items:
		world.item_catalog[id] = library.items[id]
	Shop.init_stock(world)
	for def: UnitDef in library.units.values() if world.map != null else []:
		world.navigation(def.stats.collision_radius)  # D-156: dựng sẵn cho mắt / đơn vị triệu hồi, không giật lần đầu
