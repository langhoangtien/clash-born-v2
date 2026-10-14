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


## DEF-05 (bản M2.1): còn sống và khác đội. Tầm nhìn, state, khóa công trình thêm sau.
static func is_targetable(by: Entity, target: Entity) -> bool:
	return target != null and target.alive and target.team != by.team
