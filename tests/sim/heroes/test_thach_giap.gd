extends TestCase
## D-347: Thạch Giáp · Khiên Đá (STR, tank) — nội tại giảm sát thương vật lý sau giáp, Q Dậm Đá (choáng vùng), W Đá Lở
## (chậm + giảm sát thương địch), R Bôn Thạch (tốc chạy tối đa), talent.

const K = preload("res://tests/sim/heroes/hero_kit.gd")
const Slot := AbilityDef.Slot
const ID: StringName = &"thach_giap"
const EPS: float = 0.01


func _hit(w: World, source: Entity, target: Entity, raw: float) -> void:
	var r: DamageRequest = DamageRequest.new()
	r.source_id = source.id
	r.target_id = target.id
	r.raw = raw
	r.damage_type = DamageFormulas.DamageType.PHYSICAL
	w.damage_requests.append(r)
	w.step()


func test_D_347_thach_giap_innate_reduces_physical_after_armor() -> void:
	var w: World = K.world()
	var a: Entity = K.hero(w, ID)
	var b: Entity = K.hero(w, ID, [5, 0, 0, 0], 0, K.center() + Vector2(400, 0))
	var foe: Entity = K.dummy(w, K.center() + Vector2(0, 400))
	var hp_a: float = a.health
	var hp_b: float = b.health
	_hit(w, foe, a, 200.0)
	_hit(w, foe, b, 200.0)
	assert_near((hp_b - b.health) / (hp_a - a.health), 0.86, 0.001, "bậc 5: giảm 14% sau giáp (cùng giáp)")


func test_D_347_thach_giap_q_stun_area() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [0, 2, 0, 0])
	var inside: Entity = K.dummy(w, h.position + Vector2(250, 0))
	var outside: Entity = K.dummy(w, h.position + Vector2(-360, 0))
	w.submit(Command.cast(h.id, Slot.Q))
	K.steps(w, 15)
	assert_true(K.has_state(inside, UnitState.Id.STUNNED), "choáng trong 300")
	assert_near(100000.0 - inside.health, 100.0 * K.amp(h), 1.0, "cấp 2: 100 phép")
	assert_false(K.has_state(outside, UnitState.Id.STUNNED))


func test_D_347_thach_giap_w_slows_and_weakens_enemies() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [0, 0, 5, 0])
	var foe: Entity = K.dummy(w, h.position + Vector2(300, 0))
	var dmg: float = foe.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE)
	var ms: float = foe.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	w.submit(Command.cast(h.id, Slot.W))
	K.steps(w, 3)
	foe.stats.recompute()
	assert_near(foe.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE), dmg * 0.65, EPS, "cấp 5: giảm 35% sát thương đòn đánh")
	assert_near(foe.stats.get_stat(StatId.Id.MOVEMENT_SPEED), ms * 0.75, 1.0, "chậm 25%")
	assert_true(foe.health < 100000.0, "có sát thương phép")


func test_D_347_thach_giap_r_max_speed_three_seconds() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [0, 0, 0, 1])
	var ms: float = h.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	w.submit(Command.cast(h.id, Slot.R))
	K.steps(w, 2)
	h.stats.recompute()
	var fast: float = h.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	assert_near(fast, 550.0, EPS, "tốc chạy đặt cứng 550 (OVERRIDE, bỏ qua làm chậm)")
	assert_true(fast > ms + 100.0)
	K.steps(w, 90)
	h.stats.recompute()
	assert_near(h.stats.get_stat(StatId.Id.MOVEMENT_SPEED), ms, EPS, "hết 3 s")
