extends TestCase
## CAM-01 (D-118): camera tự do khi hero chết.


func test_CAM_01_follow_hero_alive_free_when_dead_back_on_respawn() -> void:
	var cam: DeathCamera = DeathCamera.new()
	var bounds: Rect2 = Rect2(0, 0, 8000, 8000)
	assert_eq(cam.update(true, Vector2(100, 100), Vector2.RIGHT, 1.0, bounds), Vector2(100, 100), "sống: theo hero, joystick không đẩy camera")
	assert_false(cam.active())
	var p: Vector2 = cam.update(false, Vector2(500, 500), Vector2.RIGHT, 0.5, bounds)
	assert_eq(p, Vector2(500 + DeathCamera.SPEED * 0.5, 500), "chết: bắt đầu tại chỗ chết, joystick đẩy camera")
	cam.drag(Vector2(100, -50), bounds)
	assert_eq(cam.update(false, Vector2(500, 500), Vector2.ZERO, 0.1, bounds), p + Vector2(-100, 50), "kéo map: camera đi ngược tay")
	cam.drag(Vector2(100000, 0), bounds)
	assert_eq(cam.point.x, 0.0, "không ra ngoài map")
	assert_eq(cam.update(true, Vector2(7, 7), Vector2.ZERO, 0.1, bounds), Vector2(7, 7), "hồi sinh: về theo hero")
	assert_false(cam.active())
