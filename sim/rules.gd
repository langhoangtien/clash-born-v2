class_name Rules
extends RefCounted
## Các định nghĩa dùng chung (GAME_RULES mục DEF, ST). Hệ thống hỏi ở đây, không tự
## kiểm tra (ARCHITECTURE mục 5). Thêm state ở M3 thì sửa ở đây.


## DEF-01: khoảng cách mép–mép.
static func edge_distance(a: Entity, b: Entity) -> float:
	return maxf(0.0, a.position.distance_to(b.position) - a.radius - b.radius)


## DEF-02: b trong tầm đánh của a.
static func in_attack_range(a: Entity, b: Entity) -> bool:
	return edge_distance(a, b) <= a.stats.get_stat(StatId.Id.ATTACK_RANGE)


static func is_structure(e: Entity) -> bool:
	return e.kind == Entity.Kind.TOWER or e.kind == Entity.Kind.CORE


## DEF-05 (bản M2.2): còn sống, khác đội, không phải công trình đang khóa (STR-02).
## Tầm nhìn và state thêm ở M3.
static func is_targetable(by: Entity, target: Entity) -> bool:
	return target != null and target.alive and target.team != by.team and not target.locked


## Chế độ của các nút đánh (CTL-02 ĐÁNH, CTL-03 đánh lính / đánh trụ).
enum AttackMode { ALL, CREEP, STRUCTURE }


## CTL-04: mục tiêu khóa còn giữ được (nhắm được và chưa ra khỏi `lock_break_range`).
static func lock_holds(world: World, e: Entity) -> bool:
	var target: Entity = world.find_entity(e.lock_target_id)
	return is_targetable(e, target) and edge_distance(e, target) <= world.balance.lock_break_range


## CTL-02/03: mục tiêu cho nút đánh, -1 nếu không có ai (→ đánh gió, D-46). Dùng chung cho
## người chơi và bot. Hòa: gần hơn, rồi id nhỏ hơn.
static func pick_attack_target(world: World, e: Entity, mode: AttackMode) -> int:
	if mode == AttackMode.ALL and e.lock_target_id >= 0 and lock_holds(world, e):
		return e.lock_target_id
	var search: float = e.stats.get_stat(StatId.Id.ATTACK_RANGE) + world.balance.attack_search_bonus
	var best: Array[Entity] = [null, null, null]  # hero, lính/quái, công trình
	for t: Entity in world.entities:
		if not is_targetable(e, t) or edge_distance(e, t) > search:
			continue
		var slot: int = 0 if t.kind == Entity.Kind.HERO else (2 if is_structure(t) else 1)
		var by_hp: bool = slot == 0 or (slot == 1 and mode == AttackMode.CREEP)
		if best[slot] == null or _better(e, t, best[slot], by_hp):
			best[slot] = t
	var order: Array[int] = [0, 1, 2]
	if mode == AttackMode.CREEP:
		order = [1]
	elif mode == AttackMode.STRUCTURE:
		order = [2]
	for slot: int in order:
		if best[slot] != null:
			return best[slot].id
	return -1


static func _better(e: Entity, a: Entity, b: Entity, by_hp: bool) -> bool:
	if by_hp and a.health != b.health:
		return a.health < b.health
	var da: float = edge_distance(e, a)
	var db: float = edge_distance(e, b)
	if da != db:
		return da < db
	return a.id < b.id
