class_name MatchInput
extends RefCounted
## Tầng APP (CTL-01..04): biến joystick/WASD, nút đánh (J/K/L) và chạm/click thành Command
## cho hero. Gom về tối đa một lệnh mỗi tick: gọi flush() ngay trước world.step().
## Chọn mục tiêu không làm ở đây: lệnh ATTACK_AUTO để SIM chọn lúc áp (CMD-05).

## Hướng đổi ít hơn góc này (độ) thì không gửi lệnh mới.
const ANGLE_STEP_DEG: float = 3.0
## Bán kính chạm/click vào đơn vị, tính theo bán kính đơn vị (hằng số giao diện).
const PICK_RADIUS_SCALE: float = 1.8

var world: World
var hero: Entity

var _direction: Vector2 = Vector2.ZERO
var _sent_direction: Vector2 = Vector2.ZERO
var _tap: Vector2 = Vector2.INF
var _attack_id: int = -1
## Nút đánh đang giữ theo Rules.AttackMode; nút nhấn sau cùng là nút có hiệu lực.
var _held: Array[bool] = [false, false, false]
var _active_mode: int = -1
var _press: bool = false
## Ô chiêu vừa bấm (AbilityDef.Slot), -1 = không.
var _skill: int = -1


func set_direction(dir: Vector2) -> void:
	_direction = dir.normalized() if dir.length() > 0.0 else Vector2.ZERO


## CTL-02/03: nút ĐÁNH / đánh lính / đánh trụ (hoặc J/K/L) nhấn hoặc thả.
func set_attack_held(mode: int, held: bool) -> void:
	if held and not _held[mode]:
		_active_mode = mode
		_press = true
	_held[mode] = held
	if not held and _active_mode == mode:
		_active_mode = _held.find(true)


## Nút chiêu / phím 1-2-3: tung nhanh (tự nhắm), kéo để nhắm làm ở M3.8.
func press_skill(slot: int) -> void:
	_skill = slot


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
		if Rules.is_attackable(hero, e) and e.position.distance_to(point) <= e.radius * PICK_RADIUS_SCALE:
			if best == null or e.position.distance_to(point) < best.position.distance_to(point):
				best = e
	return best


func flush() -> void:
	var command: Command = _next_command()
	if command != null:
		world.submit(command)


func _next_command() -> Command:
	if not hero.alive:
		# ECO-04: chờ hồi sinh không gửi gì; sống lại thì gửi lại hướng đang giữ.
		_tap = Vector2.INF
		_attack_id = -1
		_press = false
		_skill = -1
		_sent_direction = Vector2.ZERO
		return null
	if _skill >= 0:
		var slot: int = _skill
		_skill = -1
		_sent_direction = Vector2.ZERO  # tung xong thì joystick gửi lại hướng
		return QuickCast.command(world, hero, slot)
	if _direction != Vector2.ZERO:
		_tap = Vector2.INF
		_attack_id = -1
		_press = false
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
		return Command.attack(hero.id, target, true)
	if _active_mode >= 0 and (_press or _attack_idle()):
		_press = false
		_tap = Vector2.INF
		return Command.attack_auto(hero.id, _active_mode)
	if _tap.is_finite():
		var target: Vector2 = _tap
		_tap = Vector2.INF
		return Command.move_to(hero.id, target)
	return null


## Giữ nút: chỉ gửi lại khi không còn đòn hay lệnh đánh dang dở (CTL-03).
func _attack_idle() -> bool:
	if hero.attack_phase == Entity.AttackPhase.WINDUP:
		return false
	var busy: bool = hero.order.type == Order.Type.ATTACK or hero.order.type == Order.Type.SWING
	return not busy or hero.order.finished
