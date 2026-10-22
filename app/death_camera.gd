class_name DeathCamera
extends RefCounted
## CAM-01 (D-118): lúc hero chết, camera tự do để xem trận — joystick / WASD đẩy camera,
## kéo một ngón trên map để kéo camera. Bắt đầu tại chỗ hero chết; hồi sinh thì về theo hero.

## Tốc độ đẩy camera bằng joystick (đơn vị map / giây).
const SPEED: float = 2200.0

## Vị trí camera tự do; INF = đang theo hero.
var point: Vector2 = Vector2.INF


## Vị trí camera khung hình này: theo hero khi sống, tự do khi chết.
func update(alive: bool, hero_at: Vector2, direction: Vector2, delta: float, bounds: Rect2) -> Vector2:
	if alive:
		point = Vector2.INF
		return hero_at
	if not point.is_finite():
		point = hero_at
	point = _clamp(point + direction * SPEED * delta, bounds)
	return point


## Kéo trên map: `world_delta` là quãng ngón tay đi (đơn vị map); camera đi ngược lại.
func drag(world_delta: Vector2, bounds: Rect2) -> void:
	if point.is_finite():
		point = _clamp(point - world_delta, bounds)


## CAM-01b (D-126): chạm / kéo bản đồ nhỏ lúc chết → camera tự do nhảy tới đó và ở lại khi thả tay.
func jump(at: Vector2, bounds: Rect2) -> void:
	if point.is_finite():
		point = _clamp(at, bounds)


func active() -> bool:
	return point.is_finite()


static func _clamp(p: Vector2, bounds: Rect2) -> Vector2:
	return p.clamp(bounds.position, bounds.end)
