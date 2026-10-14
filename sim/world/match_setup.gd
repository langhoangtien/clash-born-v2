class_name MatchSetup
extends RefCounted
## Dựng các đơn vị cố định của trận từ map + content (công trình). Lính, hero thêm sau.


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
