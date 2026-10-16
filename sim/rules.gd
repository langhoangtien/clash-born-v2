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


## DEF-05: còn sống, khác đội, không phải công trình đang khóa (STR-02). Nhắm bằng chiêu.
## DEF-05: còn sống, khác đội, thấy được (VIS), không UNTARGETABLE (ST-12). MAGIC_IMMUNE chỉ chặn
## chiêu nhắm đơn vị (Abilities.accepts, ST-15), không chặn đánh thường.
static func is_targetable(by: Entity, target: Entity) -> bool:
	return is_hittable(by, target) and is_visible(by.team, target) and not has_state(target, UnitState.Id.UNTARGETABLE)


## Trúng được bởi vùng / đạn kỹ năng (ABL-07): như is_targetable nhưng không cần thấy.
static func is_hittable(by: Entity, target: Entity) -> bool:
	return target != null and target.alive and target.team != by.team and not target.locked


## DEF-04 / VIS-01: đội `team` đang thấy `e`.
static func is_visible(team: int, e: Entity) -> bool:
	return e.team == team or e.visible_mask & (1 << team) != 0


## Nhắm được bằng đánh thường: như is_targetable, trừ GHOST (ST-11).
static func is_attackable(by: Entity, target: Entity) -> bool:
	return is_targetable(by, target) and not has_state(target, UnitState.Id.GHOST)


## ST: đơn vị có trạng thái `state` (DEAD = chưa sống).
static func has_state(e: Entity, state: UnitState.Id) -> bool:
	if state == UnitState.Id.DEAD:
		return not e.alive
	return e.states & (1 << state) != 0


## ST-01, 02, 08: được di chuyển.
static func can_move(e: Entity) -> bool:
	return e.alive and e.dash == null and e.states & (1 << UnitState.Id.STUNNED | 1 << UnitState.Id.ROOTED) == 0


## ST-01, 04, 08, 11, 16: được đánh thường.
static func can_attack(e: Entity) -> bool:
	return e.alive and e.dash == null and e.states & (1 << UnitState.Id.STUNNED | 1 << UnitState.Id.DISARMED | 1 << UnitState.Id.GHOST | 1 << UnitState.Id.HEXED) == 0


## ST-01, 03, 08, 16: được dùng chiêu (cả đồ).
static func can_cast(e: Entity) -> bool:
	return e.alive and e.dash == null and e.states & (1 << UnitState.Id.STUNNED | 1 << UnitState.Id.SILENCED | 1 << UnitState.Id.HEXED) == 0


## ITM-03/08: dùng đồ — không bị câm lặng chặn; choáng, biến hình, lướt, chết thì không.
static func can_use_item(e: Entity) -> bool:
	return e.alive and e.dash == null and e.states & (1 << UnitState.Id.STUNNED | 1 << UnitState.Id.HEXED) == 0


## ST-07, 11: hệ số sát thương nhận theo loại (sau giáp, trước khiên).
## PRI-05: INVULNERABLE → miễn theo loại (GHOST, MAGIC_IMMUNE; `pierces` bỏ qua đúng bước miễn phép).
static func damage_factor(world: World, target: Entity, type: DamageFormulas.DamageType, pierces: bool = false) -> float:
	if has_state(target, UnitState.Id.INVULNERABLE):
		return 0.0
	if type == DamageFormulas.DamageType.MAGIC and not pierces and has_state(target, UnitState.Id.MAGIC_IMMUNE):
		return 0.0  # ST-15
	if has_state(target, UnitState.Id.GHOST):
		match type:
			DamageFormulas.DamageType.PHYSICAL:
				return 0.0
			DamageFormulas.DamageType.MAGIC:
				return 1.0 + world.balance.ghost_magic_amp
	return 1.0


## Chế độ của các nút đánh (CTL-02 ĐÁNH, CTL-03 đánh lính / đánh trụ).
enum AttackMode { ALL, CREEP, STRUCTURE }


## CTL-04: mục tiêu khóa còn giữ được (nhắm được và chưa ra khỏi `lock_break_range`).
static func lock_holds(world: World, e: Entity) -> bool:
	var target: Entity = world.find_entity(e.lock_target_id)
	return is_attackable(e, target) and edge_distance(e, target) <= world.balance.lock_break_range


## DEF-09: các công trình đội khác `team` (trụ, fountain) mà điểm `at` nằm trong vùng nguy hiểm
## (tầm bắn + `radius` + tower_danger_margin tính từ mép). Fountain trả về null trong mảng.
static func tower_threat_at(world: World, team: int, at: Vector2, radius: float) -> Array[Entity]:
	var out: Array[Entity] = []
	var margin: float = world.balance.tower_danger_margin
	for t: Entity in world.entities:
		if t.kind == Entity.Kind.TOWER and t.alive and t.team != team and t.team < 2:
			if at.distance_to(t.position) - t.radius <= t.stats.get_stat(StatId.Id.ATTACK_RANGE) + radius + margin:
				out.append(t)
	return out


## DEF-09: điểm `at` trong vùng fountain địch (luôn bắn).
static func in_enemy_fountain(world: World, team: int, at: Vector2, radius: float) -> bool:
	if world.map == null or team > 1 or world.map.fountain_points.size() < 2:
		return false
	return at.distance_to(world.map.fountain_point(1 - team)) <= world.balance.fountain_radius + radius + world.balance.tower_danger_margin


## DEF-10: điểm `at` an toàn cho hero `x`: ngoài vùng nguy hiểm mọi trụ địch và fountain địch,
## hoặc trụ đó đang bắn đơn vị khác, có ≥ tower_tank_creeps lính phe x trong tầm nó và máu x
## ≥ dive_min_hp. Trụ đang nhắm x thì không bao giờ an toàn trong vùng của nó.
static func is_safe_for_hero(world: World, x: Entity, at: Vector2) -> bool:
	if in_enemy_fountain(world, x.team, at, x.radius):
		return false
	var hp: float = x.health / maxf(1.0, x.stats.get_stat(StatId.Id.MAX_HP))
	for t: Entity in tower_threat_at(world, x.team, at, x.radius):
		var shooting: int = t.order.target_id if t.order.type == Order.Type.ATTACK and not t.order.finished else -1
		if shooting < 0 or shooting == x.id or hp < world.balance.dive_min_hp:
			return false
		if _tanks_under(world, t, x.team) < world.balance.tower_tank_creeps:
			return false
	return true


static func _tanks_under(world: World, tower: Entity, team: int) -> int:
	var n: int = 0
	var reach: float = tower.stats.get_stat(StatId.Id.ATTACK_RANGE) + tower.radius
	for c: Entity in world.spatial_near(tower.position, reach + 40.0, World.Phase.CONTROLLER, false):
		if c.kind == Entity.Kind.LANE_CREEP and c.alive and c.team == team and in_attack_range(tower, c):
			n += 1
	return n


## CTL-02/03: mục tiêu cho nút đánh, -1 nếu không có ai (→ đánh gió, D-46). Dùng chung cho
## người chơi và bot. Hòa: gần hơn, rồi id nhỏ hơn.
static func pick_attack_target(world: World, e: Entity, mode: AttackMode) -> int:
	if mode == AttackMode.ALL and e.lock_target_id >= 0 and lock_holds(world, e):
		return e.lock_target_id
	var search: float = e.stats.get_stat(StatId.Id.ATTACK_RANGE) + world.balance.attack_search_bonus
	var best: Array[Entity] = [null, null, null, null]  # hero, lính/quái, công trình, ward
	for t: Entity in world.entities:
		if not is_attackable(e, t) or edge_distance(e, t) > search:
			continue
		var slot: int = 0 if t.kind == Entity.Kind.HERO else (2 if is_structure(t) else (3 if t.kind == Entity.Kind.WARD else 1))
		var by_hp: bool = slot == 0 or (slot == 1 and mode == AttackMode.CREEP)
		if best[slot] == null or _better(e, t, best[slot], by_hp):
			best[slot] = t
	var order: Array[int] = [0, 1, 2, 3]  # WRD-06: nút Đánh — ward sau cùng
	if mode == AttackMode.CREEP:
		order = [3, 1]  # WRD-06: nút Lính — ward trước lính
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
