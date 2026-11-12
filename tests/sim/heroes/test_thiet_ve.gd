extends TestCase
## D-385: Thiết Vệ · Khiên Sắt (STR, tank) — nội tại Ý Chí Sắt (tầng giảm sát thương + hồi máu), Q Khiêu Khích (ST-20),
## W Gồng Sắt (tốc chạy + giáp), R Phản Kích (cứ 4 đòn bị đánh, EFF-16), talent.

const K = preload("res://tests/sim/heroes/hero_kit.gd")
const Slot := AbilityDef.Slot
const ID: StringName = &"thiet_ve"
const EPS: float = 0.001


## `n` đòn đánh thường từ `from` vào `to`, mỗi đòn một tick.
func _attacks(w: World, from: Entity, to: Entity, n: int) -> void:
	for i: int in n:
		var r: DamageRequest = DamageRequest.attack(from, to.id)
		r.raw = 1.0
		w.damage_requests.append(r)
		w.step()


func _stacks(h: Entity, id: StringName) -> int:
	for inst: EffectInstance in h.effects:
		if inst.def.id == id:
			return inst.stacks
	return 0


func test_D_385_thiet_ve_innate_stacks_reduce_damage_and_heal() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [1, 0, 0, 0])
	var foe: Entity = K.dummy(w, h.position + Vector2(100, 0))
	var regen: float = h.stats.get_stat(StatId.Id.HP_REGEN)
	_attacks(w, h, foe, 20)
	h.stats.recompute()
	assert_eq(_stacks(h, &"thiet_ve_iron_stack"), 16, "tối đa 16 tầng")
	assert_near(h.stats.get_stat(StatId.Id.DAMAGE_TAKEN_MULTIPLIER), 0.68, EPS, "T3: 16 × −2% = −32% (cộng dồn)")
	assert_near(h.stats.get_stat(StatId.Id.HP_REGEN) - regen, 0.016 * h.stats.get_stat(StatId.Id.MAX_HP), 0.5, "T3: 16 × 0,1% máu tối đa / s")
	K.steps(w, 61)
	h.stats.recompute()
	assert_eq(_stacks(h, &"thiet_ve_iron_stack"), 0, "2 s không đánh thì hết tầng")
	assert_near(h.stats.get_stat(StatId.Id.DAMAGE_TAKEN_MULTIPLIER), 1.0, EPS)


func test_D_385_thiet_ve_q_taunts_enemies_in_radius() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [0, 1, 0, 0])
	var inside: Entity = K.dummy(w, h.position + Vector2(250, 0))
	var outside: Entity = K.dummy(w, h.position + Vector2(-380, 0))
	w.submit(Command.cast(h.id, Slot.Q))
	K.steps(w, 12)
	assert_true(K.has_state(inside, UnitState.Id.TAUNTED), "trong 300: bị khiêu khích")
	assert_eq(inside.order.target_id, h.id, "bị ép đánh Thiết Vệ")
	assert_false(K.has_state(outside, UnitState.Id.TAUNTED))
	K.steps(w, 50)
	assert_false(K.has_state(inside, UnitState.Id.TAUNTED), "cấp 1: 1,6 s")


func test_D_385_thiet_ve_q_pierces_magic_immunity() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [0, 1, 0, 0])
	var foe: Entity = K.dummy(w, h.position + Vector2(200, 0))
	var bkb: EffectDef = EffectDef.new()
	bkb.id = &"test_bkb"
	bkb.states = [UnitState.Id.MAGIC_IMMUNE] as Array[UnitState.Id]
	Effects.apply(w, foe, bkb, foe, {}, "5")
	w.submit(Command.cast(h.id, Slot.Q))
	K.steps(w, 12)
	assert_true(K.has_state(foe, UnitState.Id.TAUNTED), "T2: xuyên miễn phép")
	var inst: EffectInstance = null
	for i: EffectInstance in foe.effects:
		if i.def.id == &"thiet_ve_taunt":
			inst = i
	assert_eq(inst.def.dispel, EffectDef.Dispel.STRONG, "T2: chỉ thanh tẩy mạnh gỡ")
	assert_true(inst.def.tags.has(&"debuff"), "T2: kháng hiệu ứng rút ngắn (debuff)")


func test_D_385_thiet_ve_w_speed_and_armor() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [0, 0, 5, 0])
	var ms: float = h.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	var armor: float = h.stats.get_stat(StatId.Id.PHYSICAL_ARMOR)
	w.submit(Command.cast(h.id, Slot.W))
	K.steps(w, 2)
	h.stats.recompute()
	assert_near(h.stats.get_stat(StatId.Id.MOVEMENT_SPEED), ms * 1.3, 1.0, "+30% tốc chạy")
	assert_near(h.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), armor + 14.0, EPS, "cấp 5: +14 giáp")
	K.steps(w, 150)
	h.stats.recompute()
	assert_near(h.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), armor, EPS, "hết 5 s")


func test_D_385_thiet_ve_r_every_fourth_hit_damages_around() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [0, 0, 0, 1])
	var attacker: Entity = K.dummy(w, h.position + Vector2(100, 0))
	var near: Entity = K.dummy(w, h.position + Vector2(0, 250))
	var far: Entity = K.dummy(w, h.position + Vector2(0, -420))
	_attacks(w, attacker, h, 3)
	assert_near(near.health, 100000.0, EPS, "3 đòn: chưa phản kích")
	_attacks(w, attacker, h, 1)
	var expected: float = DamageFormulas.final_damage(80.0 + 0.4 * h.stats.get_stat(StatId.Id.STRENGTH), DamageFormulas.DamageType.PHYSICAL,
		near.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), 0.0, 1.0, w.balance) * K.amp(h)  # CMB-13
	assert_near(100000.0 - near.health, expected, 1.0, "đòn thứ 4: vật lý 80 + 40% STR trong 300")
	assert_near(far.health, 100000.0, EPS, "ngoài 300 không trúng")
	assert_true(attacker.health < 100000.0, "kẻ đánh cũng trúng")


func test_D_385_thiet_ve_r_ignores_structure_hits() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [0, 0, 0, 1])
	var tower: Entity = K.dummy(w, h.position + Vector2(100, 0), Entity.Kind.TOWER)
	var near: Entity = K.dummy(w, h.position + Vector2(0, 250))
	_attacks(w, tower, h, 8)
	assert_near(near.health, 100000.0, EPS, "đòn của công trình không tính")


func test_D_385_thiet_ve_talent_q_ii_longer_taunt() -> void:
	var w: World = K.world()
	var h: Entity = K.hero20(w, ID, Slot.Q)
	var foe: Entity = K.dummy(w, h.position + Vector2(200, 0))
	w.submit(Command.cast(h.id, Slot.Q))
	K.steps(w, 12 + 80)
	assert_true(K.has_state(foe, UnitState.Id.TAUNTED), "Q II: 2,4 + 0,5 s — sau ~2,7 s vẫn còn")
	K.steps(w, 15)
	assert_false(K.has_state(foe, UnitState.Id.TAUNTED))


func test_D_385_thiet_ve_talent_w_ii_more_armor() -> void:
	var w: World = K.world()
	var h: Entity = K.hero20(w, ID, Slot.W)
	var armor: float = h.stats.get_stat(StatId.Id.PHYSICAL_ARMOR)
	w.submit(Command.cast(h.id, Slot.W))
	K.steps(w, 2)
	h.stats.recompute()
	assert_near(h.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), armor + 18.0, EPS, "W II: 14 + 4 giáp")


func test_D_385_thiet_ve_talent_r_ii_every_third_hit() -> void:
	var w: World = K.world()
	var h: Entity = K.hero20(w, ID, Slot.R)
	var attacker: Entity = K.dummy(w, h.position + Vector2(100, 0))
	var near: Entity = K.dummy(w, h.position + Vector2(0, 250))
	_attacks(w, attacker, h, 2)
	assert_near(near.health, 100000.0, EPS)
	_attacks(w, attacker, h, 1)
	assert_true(near.health < 100000.0, "R II: đòn thứ 3 đã phản kích")
