extends SimSystem
## Hệ thống chỉ dùng trong test: mỗi đơn vị đi một bước ngẫu nhiên từ world.rng.


func run(world: World) -> void:
	for e: Entity in world.entities:
		e.position += Vector2(world.rng.randf_range(-5, 5), world.rng.randf_range(-5, 5))
		e.health = maxf(1.0, e.health - world.rng.randf())
