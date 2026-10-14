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
