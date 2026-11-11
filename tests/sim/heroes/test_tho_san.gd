extends TestCase
## D-347: Thợ Săn · Bắt Lẻ (STR, cận chiến) — không có nội tại riêng (mỗi bậc +2 mọi thuộc tính), Q Truy Kích (sát thương +
## chậm), W Phong Ấn (câm một hero), R Cuồng Săn (tốc chạy / tốc đánh / sát thương), talent.

const K = preload("res://tests/sim/heroes/hero_kit.gd")
const Slot := AbilityDef.Slot
const ID: StringName = &"tho_san"
const EPS: float = 0.01


func test_D_347_tho_san_innate_plus_two_all_attributes_per_rank() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID)
	var before: Vector3 = Vector3(h.stats.get_stat(StatId.Id.STRENGTH), h.stats.get_stat(StatId.Id.AGILITY), h.stats.get_stat(StatId.Id.INTELLIGENCE))
	Abilities.set_rank(w, h, Abilities.of(h, Slot.INNATE), 5)
	h.stats.recompute()
	var after: Vector3 = Vector3(h.stats.get_stat(StatId.Id.STRENGTH), h.stats.get_stat(StatId.Id.AGILITY), h.stats.get_stat(StatId.Id.INTELLIGENCE))
	assert_true((after - before).is_equal_approx(Vector3(10, 10, 10)), "bậc 5: +10 mọi thuộc tính " + str(after - before))


func test_D_347_tho_san_q_damage_and_slow() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [0, 3, 0, 0])
	var foe: Entity = K.dummy(w, h.position + Vector2(400, 0))
	var ms: float = foe.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	w.submit(Command.cast(h.id, Slot.Q, foe.id))
	K.steps(w, 3)
	assert_near(100000.0 - foe.health, 160.0 * K.amp(h), 1.0, "cấp 3: 160 vật lý (giáp 0)")
	foe.stats.recompute()
	assert_near(foe.stats.get_stat(StatId.Id.MOVEMENT_SPEED), ms * 0.7, 1.0, "chậm 30%")


func test_D_347_tho_san_w_silences_heroes_only() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [0, 0, 1, 0])
	var foe: Entity = K.dummy(w, h.position + Vector2(400, 0))
	var creep: Entity = K.dummy(w, h.position + Vector2(-300, 0), Entity.Kind.LANE_CREEP)
	w.submit(Command.cast(h.id, Slot.W, creep.id))
	K.steps(w, 3)
	assert_false(K.has_state(creep, UnitState.Id.SILENCED), "không nhắm lính")
	w.submit(Command.cast(h.id, Slot.W, foe.id))
	K.steps(w, 3)
	assert_true(K.has_state(foe, UnitState.Id.SILENCED), "câm hero")
	K.steps(w, 45)
	assert_false(K.has_state(foe, UnitState.Id.SILENCED), "cấp 1: 1,5 s")


func test_D_347_tho_san_r_frenzy_buffs_then_talent_longer() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [0, 0, 0, 3])
	var dmg: float = h.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE)
	var aspd: float = h.stats.get_stat(StatId.Id.ATTACK_SPEED)
	w.submit(Command.cast(h.id, Slot.R))
	K.steps(w, 2)
	h.stats.recompute()
	assert_near(h.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE) - dmg, 70.0, EPS, "cấp 3: +70 sát thương")
	assert_near(h.stats.get_stat(StatId.Id.ATTACK_SPEED) - aspd, 0.8, EPS, "+0,8 tốc đánh")
	K.steps(w, 30 * 6)
	h.stats.recompute()
	assert_near(h.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE), dmg, EPS, "hết 6 s")
	var t: Entity = K.hero20(w, ID, Slot.R)
	w.submit(Command.cast(t.id, Slot.R))
	K.steps(w, 2 + 30 * 7)
	assert_true(t.effects.any(func(i: EffectInstance) -> bool: return i.def.id == &"tho_san_frenzy"), "talent R II: 9 s")
