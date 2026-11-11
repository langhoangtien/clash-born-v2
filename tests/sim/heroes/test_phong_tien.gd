extends TestCase
## D-347: Phong Tiễn · Cung Gió (AGI, đánh xa) — nội tại tốc đánh theo AGI (STAT-06), Q Lướt Gió (tốc chạy + né 100%),
## W Gió Độc (vùng: sát thương phép + chậm + câm), R Phong Thần (bị động +AGI), talent.

const K = preload("res://tests/sim/heroes/hero_kit.gd")
const Slot := AbilityDef.Slot
const ID: StringName = &"phong_tien"
const EPS: float = 0.01


func test_D_347_phong_tien_innate_attack_speed_from_agility() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID)
	var as0: float = h.stats.get_stat(StatId.Id.ATTACK_SPEED)
	Abilities.set_rank(w, h, Abilities.of(h, Slot.INNATE), 5)
	h.stats.recompute()
	var agi: float = h.stats.get_stat(StatId.Id.AGILITY)
	assert_near(h.stats.get_stat(StatId.Id.ATTACK_SPEED) - as0, 0.6 * w.balance.attack_speed_per_agility * agi, 0.0001,
		"bậc 5: thêm 60% phần tốc đánh mà AGI cho")
	Abilities.set_rank(w, h, Abilities.of(h, Slot.R), 1)
	h.stats.recompute()
	var agi2: float = h.stats.get_stat(StatId.Id.AGILITY)
	assert_near(agi2 - agi, 25.0, EPS, "R bậc 1: +25 AGI")
	assert_near(h.stats.get_stat(StatId.Id.ATTACK_SPEED) - as0, 1.6 * w.balance.attack_speed_per_agility * agi2
		- w.balance.attack_speed_per_agility * agi, 0.0001, "AGI từ R cũng cho tốc đánh nội tại (theo AGI hiện tại)")


func test_D_347_phong_tien_q_speed_and_full_evasion() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [0, 1, 0, 0])
	var ms: float = h.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	var foe: Entity = K.dummy(w, h.position + Vector2(60, 0))
	foe.stats.set_base(StatId.Id.ATTACK_RANGE, 150)
	foe.stats.recompute()
	w.submit(Command.cast(h.id, Slot.Q))
	K.steps(w, 2)
	h.stats.recompute()
	assert_true(h.stats.get_stat(StatId.Id.MOVEMENT_SPEED) > ms * 1.2, "+25%% tốc chạy (%.0f → %.0f)" % [ms, h.stats.get_stat(StatId.Id.MOVEMENT_SPEED)])
	var hp: float = h.health
	w.submit(Command.attack(foe.id, h.id))
	K.steps(w, 80)
	assert_true(h.health >= hp - EPS, "né mọi đòn đánh trong 3 s")
	K.steps(w, 60)
	assert_true(h.health < hp, "hết 3 s: trúng đòn lại")


func test_D_347_phong_tien_w_poison_area_slow_silence() -> void:
	var w: World = K.world()
	var h: Entity = K.hero(w, ID, [0, 0, 2, 0])
	var at: Vector2 = h.position + Vector2(600, 0)
	var inside: Entity = K.dummy(w, at + Vector2(0, 200))
	var outside: Entity = K.dummy(w, at + Vector2(0, 360))
	var ms: float = inside.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	w.submit(Command.cast(h.id, Slot.W, -1, at))
	K.steps(w, 12)
	assert_near(100000.0 - inside.health, 100.0 * K.amp(h), 1.0, "cấp 2: 100 phép (giáp phép 0)")
	assert_true(K.has_state(inside, UnitState.Id.SILENCED), "câm")
	inside.stats.recompute()
	assert_near(inside.stats.get_stat(StatId.Id.MOVEMENT_SPEED), ms * 0.75, 1.0, "chậm 25%")
	assert_near(outside.health, 100000.0, EPS)
	K.steps(w, 45)
	assert_false(K.has_state(inside, UnitState.Id.SILENCED), "cấp 2: câm 1,5 s")


func test_D_347_phong_tien_r_talent_more_agility() -> void:
	var w: World = K.world()
	var a: Entity = K.hero20(w, ID)
	var b: Entity = K.hero20(w, ID, Slot.R)
	assert_near(b.stats.get_stat(StatId.Id.AGILITY) - a.stats.get_stat(StatId.Id.AGILITY), 15.0, EPS, "talent R II: +15 AGI")
