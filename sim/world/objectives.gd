class_name Objectives
extends RefCounted
## STR-02: khóa công trình. T1 luôn mở; T2/T3 mở khi mọi trụ điều kiện đổ; T4 mở khi bất
## kỳ trụ điều kiện (T3) đổ; nhà chính mở khi cả hai T4 cùng đội đổ. Điều kiện lấy từ map.


static func refresh_locks(world: World) -> void:
	for e: Entity in world.entities:
		if Rules.is_structure(e):
			e.locked = not is_unlocked(world, e)


static func is_unlocked(world: World, e: Entity) -> bool:
	var map: MapLayout = world.map
	if e.kind == Entity.Kind.CORE:
		for i: int in range(map.tower_ids.size()):
			if map.tower_teams[i] == e.team and map.tower_tiers[i] == 4 and not _down(world, map.tower_ids[i]):
				return false
		return true
	var index: int = map.tower_index(String(e.structure_id))
	var needs: PackedStringArray = map.tower_prerequisites[index]
	if needs.is_empty():
		return true
	if map.tower_tiers[index] == 4:
		return Array(needs).any(func(id: String) -> bool: return _down(world, id))
	return Array(needs).all(func(id: String) -> bool: return _down(world, id))


static func _down(world: World, structure_id: String) -> bool:
	return world.destroyed_structures.has(StringName(structure_id))
