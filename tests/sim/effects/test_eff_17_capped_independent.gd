extends TestCase
## EFF-17 (D-395): tầng độc lập có trần — một test cho mỗi dòng bảng tương tác.


func _world() -> World:
	return World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)


func _unit(w: World, team: int = 0) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 1000)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.7)
	return w.add_entity(e)


func _def(cap: int) -> EffectDef:
	var d: EffectDef = EffectDef.new()
	d.id = &"test_layer"
	d.stacking = EffectDef.Stacking.INDEPENDENT
	d.max_stacks = cap
	var m: ModifierDef = ModifierDef.new()
	m.stat = &"physical_armor"
	m.value = "10"
	d.modifiers = [m] as Array[ModifierDef]
	return d


func _copies(e: Entity, id: StringName = &"test_layer") -> Array[EffectInstance]:
	var out: Array[EffectInstance] = []
	for inst: EffectInstance in e.effects:
		if inst.def.id == id:
			out.append(inst)
	return out


func test_EFF_17_adds_until_cap() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	var d: EffectDef = _def(3)
	for i: int in 2:
		Effects.apply(w, e, d, e, {}, "5")
	assert_eq(_copies(e).size(), 2, "chưa đủ trần: thêm bản")
	for i: int in 3:
		Effects.apply(w, e, d, e, {}, "5")
	assert_eq(_copies(e).size(), 3, "không vượt trần")


func test_EFF_17_at_cap_replaces_oldest() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	var d: EffectDef = _def(3)
	var first: EffectInstance = Effects.apply(w, e, d, e, {}, "5")
	Effects.apply(w, e, d, e, {}, "5")
	Effects.apply(w, e, d, e, {}, "5")
	var newest: EffectInstance = Effects.apply(w, e, d, e, {}, "5")
	assert_false(_copies(e).has(first), "bản cũ nhất bị gỡ")
	assert_true(_copies(e).has(newest), "bản mới được thêm")
	var reason: StringName = &""
	for ev: GameEvent in w.events:
		if ev.type == &"effect_removed" and ev.effect == first:
			reason = ev.reason
	assert_eq(reason, &"replaced")


func test_EFF_17_other_source_counted_separately() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	var a: Entity = _unit(w, 1)
	var b: Entity = _unit(w, 1)
	var d: EffectDef = _def(2)
	for i: int in 3:
		Effects.apply(w, e, d, a, {}, "5")
		Effects.apply(w, e, d, b, {}, "5")
	assert_eq(_copies(e).size(), 4, "mỗi nguồn trần 2")


func test_EFF_17_each_copy_expires_separately() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	var d: EffectDef = _def(16)
	for i: int in 3:
		Effects.apply(w, e, d, e, {}, "1")
		for t: int in 10:
			w.step()
	for t: int in 5:
		w.step()
	assert_eq(_copies(e).size(), 2, "tick 35: bản áp ở tick 0 đã hết (1 s), hai bản sau còn")
	for t: int in 10:
		w.step()
	assert_eq(_copies(e).size(), 1, "tick 45: bản thứ hai hết")
	for t: int in 10:
		w.step()
	assert_eq(_copies(e).size(), 0, "tick 55: bản cuối hết riêng")


func test_EFF_17_modifiers_add_per_copy() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	var base: float = e.stats.get_stat(StatId.Id.PHYSICAL_ARMOR)
	var d: EffectDef = _def(3)
	for i: int in 5:
		Effects.apply(w, e, d, e, {}, "5")
	e.stats.recompute()
	assert_near(e.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), base + 30.0, 0.001, "3 bản × 10")


func test_EFF_17_dispel_and_death_remove_copies() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	var d: EffectDef = _def(3)
	for i: int in 3:
		Effects.apply(w, e, d, e, {}, "5")
	Effects.remove_on_death(w, e)
	assert_eq(_copies(e).size(), 0, "chết gỡ hết (EFF-13)")


func test_EFF_17_max_stacks_one_means_no_cap() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	var d: EffectDef = _def(1)
	for i: int in 5:
		Effects.apply(w, e, d, e, {}, "5")
	assert_eq(_copies(e).size(), 5, "max_stacks 1 (mặc định): không trần như cũ")
