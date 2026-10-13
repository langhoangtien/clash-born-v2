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


func set_direction(dir: Vector2) -> void:
	_direction = dir.normalized() if dir.length() > 0.0 else Vector2.ZERO


func tap_world_point(point: Vector2) -> void:
	_tap = point


func flush() -> void:
	var command: Command = _next_command()
	if command != null:
		world.submit(command)


func _next_command() -> Command:
	if _direction != Vector2.ZERO:
		_tap = Vector2.INF
		if _sent_direction != Vector2.ZERO and rad_to_deg(absf(_sent_direction.angle_to(_direction))) < ANGLE_STEP_DEG:
			return null
		_sent_direction = _direction
		return Command.move_dir(hero.id, _direction)
	if _sent_direction != Vector2.ZERO:
		_sent_direction = Vector2.ZERO
		return Command.stop(hero.id)
	if _tap.is_finite():
		var target: Vector2 = _tap
		_tap = Vector2.INF
		return Command.move_to(hero.id, target)
	return null
