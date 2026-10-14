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
