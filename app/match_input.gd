class_name MatchInput
extends RefCounted
## Tầng APP (CTL-01): biến hướng joystick/WASD và chạm map thành Command cho hero.
## Gom về tối đa một lệnh mỗi tick: gọi flush() ngay trước world.step().

## Hướng đổi ít hơn góc này (độ) thì không gửi lệnh mới.
const ANGLE_STEP_DEG: float = 3.0

var world: World
var hero: Entity

var _direction: Vector2 = Vector2.ZERO
var _sent_direction: Vector2 = Vector2.ZERO
var _tap: Vector2 = Vector2.INF
var _attack_id: int = -1
## Bán kính chạm/click vào đơn vị, tính theo bán kính đơn vị (hằng số giao diện).
const PICK_RADIUS_SCALE: float = 1.8


func set_direction(dir: Vector2) -> void:
	_direction = dir.normalized() if dir.length() > 0.0 else Vector2.ZERO


## Chạm/click vào map (CTL-01, CTL-04): trúng đơn vị địch → khóa và đánh; chỗ trống →
## đi tới chỉ khi `allow_move` (PC chuột phải). Điện thoại không có chạm map để đi (D-45).
func click_world_point(point: Vector2, allow_move: bool) -> void:
	var enemy: Entity = _enemy_at(point)
	if enemy != null:
		_attack_id = enemy.id
	elif allow_move:
		_tap = point


func _enemy_at(point: Vector2) -> Entity:
	var best: Entity = null
	for e: Entity in world.entities:
		if Rules.is_targetable(hero, e) and e.position.distance_to(point) <= e.radius * PICK_RADIUS_SCALE:
			if best == null or e.position.distance_to(point) < best.position.distance_to(point):
				best = e
	return best


func flush() -> void:
	var command: Command = _next_command()
	if command != null:
		world.submit(command)


func _next_command() -> Command:
	if _direction != Vector2.ZERO:
		_tap = Vector2.INF
		_attack_id = -1
		if _sent_direction != Vector2.ZERO and rad_to_deg(absf(_sent_direction.angle_to(_direction))) < ANGLE_STEP_DEG:
			return null
		_sent_direction = _direction
		return Command.move_dir(hero.id, _direction)
	if _sent_direction != Vector2.ZERO:
		_sent_direction = Vector2.ZERO
		return Command.stop(hero.id)
	if _attack_id >= 0:
		var target: int = _attack_id
		_attack_id = -1
		return Command.attack(hero.id, target)
	if _tap.is_finite():
		var target: Vector2 = _tap
		_tap = Vector2.INF
		return Command.move_to(hero.id, target)
	return null
