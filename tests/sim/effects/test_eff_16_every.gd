extends TestCase
## EFF-16 (D-384): trigger "cứ N lần" (`every`).

const F = preload("res://tests/content/fixture_content.gd")


func _world() -> Array:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	var me: Entity = UnitFactory.hero(w, lib.heroes[&"brakk"], 0, Vector2(4000, 4000))
	var foe: Entity = UnitFactory.hero(w, lib.heroes[&"noctis"], 1, Vector2(4100, 4000))
	for e: Entity in [me, foe]:
		e.stats.set_base(StatId.Id.MAX_HP, 100000.0)
		e.health = 100000.0
	return [w, me, foe, lib]


## Bị động "cứ `n` đòn bị đánh trúng thì …" (vai TARGET trên attack_landed), tùy điều kiện / tag.
func _every_def(n: String, condition: StringName = &"", passive: bool = false) -> EffectDef:
	var t: TriggerDef = TriggerDef.new()
	t.event = &"attack_landed"
	t.role = TriggerDef.Role.TARGET
	t.every = n
	t.condition = condition
	var d: EffectDef = EffectDef.new()
	d.id = &"test_every"
	d.duration = "0"
	d.triggers = [t] as Array[TriggerDef]
	if passive:
		d.tags = [&"passive"] as Array[StringName]
	return d


## Đánh `hits` đòn từ `from` vào `to` (mỗi đòn một tick); trả về số lần trigger của `inst` chạy.
func _hits(w: World, from: Entity, to: Entity, hits: int, inst: EffectInstance) -> int:
	var fired: int = 0
	for i: int in range(hits):
		var r: DamageRequest = DamageRequest.attack(from, to.id)
		r.raw = 1.0
		w.damage_requests.append(r)
		w.step()
		for ev: GameEvent in w.events:
			if ev.type == &"effect_triggered" and ev.effect == inst:
				fired += 1
	return fired


func test_EFF_16_fires_on_every_nth_event() -> void:
	var s: Array = _world()
	var inst: EffectInstance = Effects.apply(s[0], s[1], _every_def("3"), s[1])
	assert_eq(_hits(s[0], s[2], s[1], 7, inst), 2, "7 đòn, cứ 3 đòn: chạy 2 lần")


func test_EFF_16_counter_resets_after_fire() -> void:
	var s: Array = _world()
	var inst: EffectInstance = Effects.apply(s[0], s[1], _every_def("3"), s[1])
	assert_eq(_hits(s[0], s[2], s[1], 3, inst), 1, "đòn thứ 3 chạy")
	assert_eq(_hits(s[0], s[2], s[1], 2, inst), 0, "đếm lại từ 0: đòn 4, 5 chưa")
	assert_eq(_hits(s[0], s[2], s[1], 1, inst), 1, "đòn 6 chạy")


func test_EFF_16_condition_failed_events_not_counted() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var lib: ContentLibrary = s[3]
	var tower: Entity = UnitFactory.unit(w, lib.units[&"tower_t1"], Entity.Kind.TOWER, 1, Vector2(4300, 4000))
	var inst: EffectInstance = Effects.apply(w, s[1], _every_def("3", &"target_not_structure"), s[1])
	assert_eq(_hits(w, tower, s[1], 5, inst), 0, "đòn của công trình không tính")
	assert_eq(_hits(w, s[2], s[1], 3, inst), 1, "đòn của hero tính từ 0")


func test_EFF_16_missed_attack_not_counted() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var dodge: EffectDef = EffectDef.new()
	dodge.id = &"test_dodge"
	dodge.duration = "0"
	var m: ModifierDef = ModifierDef.new()
	m.stat = &"evasion"
	m.value = "1"
	dodge.modifiers = [m] as Array[ModifierDef]
	Effects.apply(w, s[1], dodge, s[1])
	var inst: EffectInstance = Effects.apply(w, s[1], _every_def("2"), s[1])
	assert_eq(_hits(w, s[2], s[1], 5, inst), 0, "né hết: không có attack_landed, không đếm")


func test_EFF_16_counter_lost_when_effect_removed() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var def: EffectDef = _every_def("3")
	var inst: EffectInstance = Effects.apply(w, s[1], def, s[1])
	assert_eq(_hits(w, s[2], s[1], 2, inst), 0)
	Effects.remove(w, s[1], inst, &"removed")
	var again: EffectInstance = Effects.apply(w, s[1], def, s[1])
	assert_eq(_hits(w, s[2], s[1], 2, again), 0, "áp lại thì đếm lại từ 0")
	assert_eq(_hits(w, s[2], s[1], 1, again), 1)


func test_EFF_16_hexed_passive_does_not_count() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var inst: EffectInstance = Effects.apply(w, s[1], _every_def("3", &"", true), s[1])
	var hex: EffectDef = EffectDef.new()
	hex.id = &"test_hex"
	hex.states = [UnitState.Id.HEXED] as Array[UnitState.Id]
	var h: EffectInstance = Effects.apply(w, s[1], hex, s[2], {}, "10")
	assert_eq(_hits(w, s[2], s[1], 4, inst), 0, "biến hình: bị động tắt, không đếm")
	Effects.remove(w, s[1], h, &"removed")
	assert_eq(_hits(w, s[2], s[1], 2, inst), 0, "hết biến hình: mới đếm 2")
	assert_eq(_hits(w, s[2], s[1], 1, inst), 1)


func test_EFF_16_every_with_chance_or_cooldown_rejected() -> void:
	for field: String in ["chance", "cooldown"]:
		var h: HeroDef = F.hero()
		var t: TriggerDef = TriggerDef.new()
		t.event = &"attack_landed"
		t.every = "4"
		t.set(field, "0.5")
		var d: EffectDef = EffectDef.new()
		d.id = &"test_every_bad"
		d.triggers = [t] as Array[TriggerDef]
		var a: ApplyEffectAction = ApplyEffectAction.new()
		a.effect = d
		h.q.on_cast = [a] as Array[ActionDef]
		var errs: String = "\n".join(ContentValidator.errors(F.library_with([h] as Array[GameDef])))
		assert_true(errs.contains("EFF-16"), "every + %s phải bị validator bắt: %s" % [field, errs])


func test_EFF_16_counter_in_world_hash() -> void:
	var s: Array = _world()
	var inst: EffectInstance = Effects.apply(s[0], s[1], _every_def("3"), s[1])
	var before: PackedByteArray = WorldHash.entity(s[1])
	_hits(s[0], s[2], s[1], 1, inst)
	var after_hit: PackedByteArray = WorldHash.entity(s[1])
	inst.trigger_counts[0] = 0
	var reset: PackedByteArray = WorldHash.entity(s[1])
	assert_ne(after_hit, reset, "chỉ khác bộ đếm thì mã băm cũng khác")
	assert_ne(before, after_hit)
