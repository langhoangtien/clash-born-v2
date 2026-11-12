extends TestCase
## CMB-18 (D-386): đòn đánh phụ — một test cho mỗi dòng bảng tương tác.


func _world() -> World:
	return World.new(7, load("res://content/balance/balance_settings.tres") as BalanceSettings)


func _unit(w: World, team: int, at: Vector2, hp: float = 100000.0) -> Entity:
	var e: Entity = Entity.new()
	e.kind = Entity.Kind.HERO
	e.team = team
	e.radius = 24.0
	e.position = at
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, hp)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	e.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, 100)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, 150)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300)
	e.attack_point = 0.1
	e.stats.recompute()
	e.health = hp
	return w.add_entity(e)


func _extra_def(chance: String, delay: String = "0.2", id: StringName = &"test_double_shot") -> EffectDef:
	var d: EffectDef = EffectDef.new()
	d.id = id
	d.duration = "0"
	d.extra_attack_chance = chance
	d.extra_attack_delay = delay
	return d


func _state_def(id: StringName, state: UnitState.Id) -> EffectDef:
	var d: EffectDef = EffectDef.new()
	d.id = id
	d.states = [state] as Array[UnitState.Id]
	return d


## Cặp kẻ đánh (có đòn phụ `chance`) – mục tiêu đứng sát.
func _pair(chance: String, target_hp: float = 100000.0) -> Array:
	var w: World = _world()
	var a: Entity = _unit(w, 0, Vector2(1000, 1000))
	var t: Entity = _unit(w, 1, Vector2(1100, 1000), target_hp)
	if chance != "":
		Effects.apply(w, a, _extra_def(chance), a)
	w.submit(Command.attack(a.id, t.id))
	return [w, a, t]


## Chạy `ticks` tick, đếm sự kiện của kẻ đánh `a` theo loại.
func _count(w: World, a: Entity, ticks: int) -> Dictionary:
	var out: Dictionary = {&"attack_started": 0, &"attack_landed": 0, &"attack_missed": 0, &"extra_attack": 0, &"crit": 0}
	for i: int in ticks:
		w.step()
		for ev: GameEvent in w.events:
			if ev.source_id == a.id and out.has(ev.type):
				out[ev.type] += 1
				if ev.type == &"attack_landed" and ev.reason == &"crit":
					out[&"crit"] += 1
	return out


## Chạy tới khi đòn chính đầu tiên ra (đòn cận chiến trúng ngay tick đó).
func _until_first_hit(w: World, a: Entity) -> int:
	for i: int in 120:
		w.step()
		for ev: GameEvent in w.events:
			if ev.source_id == a.id and (ev.type == &"attack_landed" or ev.type == &"attack_missed"):
				return w.tick
	fail("không có đòn nào ra")
	return -1


func test_CMB_18_extra_attack_fires_after_delay() -> void:
	var s: Array = _pair("1")
	var w: World = s[0]
	var a: Entity = s[1]
	var t0: int = _until_first_hit(w, a)
	var fired_at: int = -1
	for i: int in 20:
		w.step()
		for ev: GameEvent in w.events:
			if ev.type == &"extra_attack" and ev.source_id == a.id and fired_at < 0:
				fired_at = w.tick
	assert_eq(fired_at - t0, SimClock.seconds_to_ticks(0.2), "đánh thêm sau đúng 0,2 s")


func test_CMB_18_uses_prd() -> void:
	var never: Array = _pair("0")
	var c0: Dictionary = _count(never[0], never[1], 30 * 20)
	assert_eq(c0[&"extra_attack"], 0, "tỉ lệ 0: không bao giờ")
	var half: Array = _pair("0.5")
	var c: Dictionary = _count(half[0], half[1], 30 * 20)
	var mains: int = c[&"attack_started"]
	assert_true(c[&"extra_attack"] > mains * 0.25 and c[&"extra_attack"] < mains * 0.75, "50%%: %d / %d" % [c[&"extra_attack"], mains])


func test_CMB_18_does_not_consume_attack_cooldown() -> void:
	var plain: Array = _pair("")
	var doubled: Array = _pair("1")
	var p: Dictionary = _count(plain[0], plain[1], 30 * 10)
	var d: Dictionary = _count(doubled[0], doubled[1], 30 * 10)
	assert_eq(d[&"attack_started"], p[&"attack_started"], "số đòn chính không đổi (không tốn hồi đòn, không vung tay)")
	assert_true(d[&"attack_landed"] >= 2 * d[&"attack_started"] - 1, "mỗi đòn chính thêm một đòn phụ trúng")


func test_CMB_18_rolls_evasion_and_crit_separately() -> void:
	var s: Array = _pair("1")
	var w: World = s[0]
	var a: Entity = s[1]
	var t: Entity = s[2]
	var dodge: EffectDef = EffectDef.new()
	dodge.id = &"test_dodge"
	dodge.duration = "0"
	var m: ModifierDef = ModifierDef.new()
	m.stat = &"evasion"
	m.value = "1"
	dodge.modifiers = [m] as Array[ModifierDef]
	Effects.apply(w, t, dodge, t)
	var c: Dictionary = _count(w, a, 30 * 5)
	assert_eq(c[&"attack_landed"], 0)
	assert_eq(c[&"attack_missed"], c[&"attack_started"] + c[&"extra_attack"], "đòn phụ cũng bị né (xét né riêng)")
	var s2: Array = _pair("1")
	var crit: EffectDef = EffectDef.new()
	crit.id = &"test_crit"
	crit.duration = "0"
	crit.crit_chance = "1"
	crit.crit_multiplier = "2"
	Effects.apply(s2[0], s2[1], crit, s2[1])
	var c2: Dictionary = _count(s2[0], s2[1], 30 * 5)
	assert_eq(c2[&"crit"], c2[&"attack_landed"], "đòn phụ cũng tung chí mạng")
	assert_true(c2[&"extra_attack"] > 0)


func test_CMB_18_applies_on_hit_effects() -> void:
	var s: Array = _pair("1")
	var w: World = s[0]
	var a: Entity = s[1]
	var t: Trigger_probe = Trigger_probe.new()
	var probe: EffectDef = t.def()
	var inst: EffectInstance = Effects.apply(w, a, probe, a)
	var triggered: int = 0
	var extras: int = 0
	for i: int in 30 * 5:
		w.step()
		for ev: GameEvent in w.events:
			if ev.type == &"effect_triggered" and ev.effect == inst:
				triggered += 1
			elif ev.type == &"extra_attack" and ev.source_id == a.id:
				extras += 1
	assert_true(extras > 0)
	assert_true(triggered >= 2 * extras, "trigger đánh trúng chạy cả ở đòn phụ")


class Trigger_probe:
	func def() -> EffectDef:
		var tr: TriggerDef = TriggerDef.new()
		tr.event = &"attack_landed"
		var d: EffectDef = EffectDef.new()
		d.id = &"test_on_hit_probe"
		d.duration = "0"
		d.triggers = [tr] as Array[TriggerDef]
		return d


func test_CMB_18_no_chain() -> void:
	var s: Array = _pair("1")
	var c: Dictionary = _count(s[0], s[1], 30 * 10)
	assert_true(c[&"extra_attack"] <= c[&"attack_started"], "mỗi đòn chính tối đa một đòn phụ, đòn phụ không sinh đòn phụ")
	assert_true(c[&"extra_attack"] >= c[&"attack_started"] - 1)


func test_CMB_18_cancelled_when_target_dies() -> void:
	var s: Array = _pair("1", 50.0)
	var c: Dictionary = _count(s[0], s[1], 30 * 2)
	assert_eq(c[&"attack_landed"], 1, "đòn chính hạ mục tiêu")
	assert_eq(c[&"extra_attack"], 0, "T4: mục tiêu chết thì hủy")


func test_CMB_18_cancelled_when_attacker_disabled_while_waiting() -> void:
	var s: Array = _pair("1")
	var w: World = s[0]
	var a: Entity = s[1]
	_until_first_hit(w, a)
	Effects.apply(w, a, _state_def(&"test_stun", UnitState.Id.STUNNED), s[2], {}, "0.05")
	var c: Dictionary = _count(w, a, SimClock.seconds_to_ticks(0.4))
	assert_eq(c[&"extra_attack"], 0, "T4: bị choáng trong lúc chờ thì hủy (dù hết choáng trước giờ bắn)")


func test_CMB_18_cancelled_out_of_range() -> void:
	var s: Array = _pair("1")
	var w: World = s[0]
	var a: Entity = s[1]
	_until_first_hit(w, a)
	(s[2] as Entity).position = a.position + Vector2(800, 0)
	var c: Dictionary = _count(w, a, SimClock.seconds_to_ticks(0.4))
	assert_eq(c[&"extra_attack"], 0, "T4: ra quá tầm + đệm thì hủy")


func test_CMB_18_highest_chance_only() -> void:
	var s: Array = _pair("1")
	var w: World = s[0]
	var a: Entity = s[1]
	Effects.apply(w, a, _extra_def("1", "0.1", &"test_double_shot_b"), a)
	var c: Dictionary = _count(w, a, 30 * 10)
	assert_true(c[&"extra_attack"] <= c[&"attack_started"], "hai nguồn vẫn chỉ một đòn phụ mỗi đòn chính")


func test_CMB_18_change_order_while_waiting_still_fires() -> void:
	var s: Array = _pair("1")
	var w: World = s[0]
	var a: Entity = s[1]
	_until_first_hit(w, a)
	w.submit(Command.stop(a.id))
	var c: Dictionary = _count(w, a, SimClock.seconds_to_ticks(0.4))
	assert_eq(c[&"extra_attack"], 1, "đòn chính đã ra: đổi lệnh vẫn đánh")


func test_CMB_18_pending_in_world_hash() -> void:
	var s: Array = _pair("1")
	var w: World = s[0]
	var a: Entity = s[1]
	_until_first_hit(w, a)
	assert_true(a.pending_attack != null, "đang chờ đòn phụ")
	var with_pending: PackedByteArray = WorldHash.entity(a)
	a.pending_attack = null
	assert_ne(with_pending, WorldHash.entity(a), "đòn phụ đang chờ nằm trong mã băm")
