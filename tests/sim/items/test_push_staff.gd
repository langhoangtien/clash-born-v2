extends TestCase
## D-347: Gậy Đẩy (kiểu Force Staff, chỉ ghép PushAction ABL-10) — tự đẩy theo hướng đang nhìn, đẩy người khác ra xa mình,
## không đẩy được địch kháng phép.

const K = preload("res://tests/sim/heroes/hero_kit.gd")


func _staff(w: World, h: Entity) -> int:
	return Items.SLOT_BASE + Items.give(w, h, K.lib.items[&"push_staff"])


func test_D_347_push_staff_self_dashes_forward_600() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, &"brakk", [0, 0, 0, 0], 0, w.map.world_size() * 0.5)  # giữa map: đường giữa trống
	var slot: int = _staff(w, h)
	h.facing = Vector2(1, 0)
	var start: Vector2 = h.position
	w.submit(Command.cast(h.id, slot, h.id))
	K.steps(w, 20)
	var moved: Vector2 = h.position - start
	assert_near(moved.x, 600.0, 1.0, "lao 600 theo hướng đang nhìn")
	assert_near(moved.y, 0.0, 1.0)


func test_D_347_push_staff_pushes_enemy_away_and_magic_immune_blocks() -> void:
	var w: World = K.world()
	var mid: Vector2 = w.map.world_size() * 0.5
	var h: Entity = K.hero(w, &"brakk", [0, 0, 0, 0], 0, mid - Vector2(300, 0))
	var slot: int = _staff(w, h)
	var foe: Entity = K.dummy(w, mid)  # đẩy về +x: đoạn giữa map trống
	w.submit(Command.cast(h.id, slot, foe.id))
	K.steps(w, 20)
	assert_near(foe.position.distance_to(h.position), 900.0, 1.0, "địch bị đẩy 600 ra xa mình (300 → 900)")
	assert_true(K.lib.items[&"push_staff"].cost == 2200)
	var w2: World = K.world()
	var h2: Entity = K.hero(w2, &"brakk")
	var slot2: int = _staff(w2, h2)
	var bkb: Entity = K.dummy(w2, h2.position + Vector2(0, -300))
	Effects.apply(w2, bkb, load("res://content/effects/magic_immune.tres") as EffectDef, bkb, {}, "5")
	var at: Vector2 = bkb.position
	w2.submit(Command.cast(h2.id, slot2, bkb.id))
	K.steps(w2, 20)
	assert_true(bkb.position.distance_to(at) < 1.0, "địch kháng phép không bị đẩy")
