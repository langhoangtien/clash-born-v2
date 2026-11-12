extends TestCase
## D-387: Pháo Thủ · Súng Bom (AGI, đánh xa) — nội tại Nòng Dài (+tầm đánh), Q Lựu Đạn (vùng + chậm), W Bắn Kép (CMB-18),
## R Phát Bắn Tỉa (ngắm 2 s, bị ngắt thì hủy), talent.

const K = preload("res://tests/sim/heroes/hero_kit.gd")
const Slot := AbilityDef.Slot
const ID: StringName = &"phao_thu"
const EPS: float = 0.01


func _physical(w: World, raw: float, target: Entity) -> float:
	return DamageFormulas.final_damage(raw, DamageFormulas.DamageType.PHYSICAL, target.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), 0.0, 1.0, w.balance)


func test_D_387_phao_thu_innate_adds_attack_range() -> void:
	var w: World = K.world()
	var base: Entity = K.hero(w, ID)
	var h: Entity = K.hero(w, ID, [5, 0, 0, 0], 0, K.center() + Vector2(0, 300))
	assert_near(base.stats.get_stat(StatId.Id.ATTACK_RANGE), 500.0, EPS, "tầm gốc 500")
	assert_near(h.stats.get_stat(StatId.Id.ATTACK_RANGE), 650.0, EPS, "bậc 5: +150")


func test_D_387_phao_thu_q_grenade_damages_and_slows_area() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [0, 1, 0, 0])
	var at: Vector2 = h.position + Vector2(500, 0)
	var inside: Entity = K.dummy(w, at + Vector2(200, 0))
	var outside: Entity = K.dummy(w, at + Vector2(-320, 0))
	var ms: float = inside.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	w.submit(Command.cast(h.id, Slot.Q, -1, at))
	K.steps(w, 15)
	inside.stats.recompute()
	assert_near(100000.0 - inside.health, 70.0 * K.amp(h), 1.0, "cấp 1: 70 phép trong 275")
	assert_near(inside.stats.get_stat(StatId.Id.MOVEMENT_SPEED), ms * 0.75, 1.0, "chậm 25%")
	assert_near(outside.health, 100000.0, EPS, "ngoài 275 không trúng")


func test_D_387_phao_thu_w_double_shot_rate() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [0, 0, 5, 0])
	var foe: Entity = K.dummy(w, h.position + Vector2(300, 0))
	w.submit(Command.attack(h.id, foe.id))
	var mains: int = 0
	var extras: int = 0
	for i: int in 30 * 40:
		w.step()
		for ev: GameEvent in w.events:
			if ev.source_id == h.id and ev.type == &"attack_started":
				mains += 1
			elif ev.source_id == h.id and ev.type == &"extra_attack":
				extras += 1
	assert_true(mains > 20)
	assert_true(extras > mains * 0.25 and extras < mains * 0.55, "bậc 5: ~40%% bắn 2 phát (%d / %d)" % [extras, mains])


func test_D_387_phao_thu_r_headshot_after_two_seconds() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [0, 0, 0, 1])
	var foe: Entity = K.dummy(w, h.position + Vector2(1500, 0))
	w.submit(Command.cast(h.id, Slot.R, foe.id))
	K.steps(w, 50)
	assert_near(foe.health, 100000.0, EPS, "còn đang ngắm")
	K.steps(w, 20)
	assert_near(100000.0 - foe.health, _physical(w, 300.0, foe) * K.amp(h), 1.0, "cấp 1: vật lý 300 ở tầm 1500")


func test_D_387_phao_thu_r_interrupted_is_cancelled() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [0, 0, 0, 1])
	var foe: Entity = K.dummy(w, h.position + Vector2(1500, 0))
	w.submit(Command.cast(h.id, Slot.R, foe.id))
	K.steps(w, 30)
	var stun: EffectDef = load("res://content/effects/stun.tres") as EffectDef
	Effects.apply(w, h, stun, foe, {}, "0.5")
	K.steps(w, 60)
	assert_near(foe.health, 100000.0, EPS, "ABL-03: bị choáng lúc ngắm thì hủy")


func test_D_387_phao_thu_talent_q_ii_bigger_radius() -> void:
	var w: World = K.world()
	var h: Entity = K.hero20(w, ID, Slot.Q)
	var at: Vector2 = h.position + Vector2(500, 0)
	var edge: Entity = K.dummy(w, at + Vector2(340, 0))
	w.submit(Command.cast(h.id, Slot.Q, -1, at))
	K.steps(w, 15)
	assert_true(edge.health < 100000.0, "Q II: bán kính 375")


func test_D_387_phao_thu_talent_w_ii_more_chance() -> void:
	var w: World = K.world()
	var h: Entity = K.hero20(w, ID, Slot.W)
	assert_near(Abilities.value(h, Abilities.of(h, Slot.W), &"chance"), 0.5, EPS, "W II: 40% + 10%")


func test_D_387_phao_thu_talent_r_ii_more_damage() -> void:
	var w: World = K.world()
	var h: Entity = K.hero20(w, ID, Slot.R)
	assert_near(Abilities.value(h, Abilities.of(h, Slot.R), &"damage"), 850.0, EPS, "R II: 650 + 200")
