extends TestCase
## D-132: bảy món mới — xuyên giáp phép (CMB-14), giảm hồi chiêu (ABL-19), sát thương đồ không
## khuếch đại (CMB-13), Rìu Xiềng Xích trói theo kiểu đánh (ITM-05), công thức ghép.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const NEW_ITEMS: Array[StringName] = [&"piercing_staff", &"twin_blades", &"focus_staff", &"thunder_staff",
	&"time_orb", &"shadow_dance_blade", &"chain_axe"]


func _world() -> Array:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	w.map = load(MAP_PATH) as MapLayout
	MatchSetup.add_shop(w, lib)
	return [w, lib]


func _hero(s: Array, id: StringName, at: Vector2 = Vector2(4000, 4000), team: int = 0) -> Entity:
	return UnitFactory.hero(s[0], (s[1] as ContentLibrary).heroes[id], team, at)


func _magic_hit(w: World, source: Entity, target: Entity, raw: float) -> float:
	var r: DamageRequest = DamageRequest.new()
	r.source_id = source.id
	r.target_id = target.id
	r.raw = raw
	r.damage_type = DamageFormulas.DamageType.MAGIC
	w.damage_requests.append(r)
	var before: float = target.health
	DamageSystem.resolve(w)
	return before - target.health


func test_D_132_new_items_have_cost_above_components() -> void:
	var w: World = _world()[0]
	for id: StringName in NEW_ITEMS:
		var d: ItemDef = w.item_catalog.get(id)
		assert_true(d != null, "có món %s" % id)
		assert_true(RecipeTree.fee(w, d) > 0, "%s: giá lớn hơn tổng thành phần" % id)


func test_CMB_14_magic_armor_reduction_lowers_armor_for_own_magic_damage() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var caster: Entity = _hero(s, &"myra")
	var victim: Entity = _hero(s, &"brakk", Vector2(4100, 4000), 1)
	victim.stats.add_modifier(StatModifier.make(StatId.Id.MAGIC_ARMOR, ModifierDef.Op.ADD, 10.0, 999, &""))
	victim.health = 5000.0
	w.step()
	var plain: float = _magic_hit(w, caster, victim, 100.0)
	Items.give(w, caster, w.item_catalog[&"piercing_staff"])
	w.step()
	assert_near(caster.stats.get_stat(StatId.Id.MAGIC_ARMOR_REDUCTION), 10.0, 0.001)
	var pierced: float = _magic_hit(w, caster, victim, 100.0)
	var armor: float = victim.stats.get_stat(StatId.Id.MAGIC_ARMOR)
	var k: float = w.balance.armor_coefficient
	assert_near(pierced, 100.0 * DamageFormulas.armor_multiplier(armor - 10.0, k), 0.01, "tính như mục tiêu ít hơn 10 giáp phép")
	assert_true(pierced > plain, "xuyên giáp phép gây nhiều hơn")
	assert_near(victim.stats.get_stat(StatId.Id.MAGIC_ARMOR), armor, 0.001, "không đổi giáp thật của mục tiêu")


func test_CMB_14_reduction_does_not_touch_physical_damage() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var caster: Entity = _hero(s, &"myra")
	var victim: Entity = _hero(s, &"brakk", Vector2(4100, 4000), 1)
	Items.give(w, caster, w.item_catalog[&"piercing_staff"])
	w.step()
	victim.health = 5000.0
	var r: DamageRequest = DamageRequest.new()
	r.source_id = caster.id
	r.target_id = victim.id
	r.raw = 100.0
	w.damage_requests.append(r)
	var before: float = victim.health
	DamageSystem.resolve(w)
	var k: float = w.balance.armor_coefficient
	assert_near(before - victim.health, 100.0 * DamageFormulas.armor_multiplier(victim.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), k), 0.01)


func test_ABL_19_cooldown_reduction_multiplies_across_sources() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var hero: Entity = _hero(s, &"myra")
	Items.give(w, hero, w.item_catalog[&"time_orb"])
	w.step()
	assert_near(hero.stats.get_stat(StatId.Id.COOLDOWN_REDUCTION), 0.2, 0.0001)
	Items.give(w, hero, w.item_catalog[&"time_orb"])
	w.step()
	assert_near(hero.stats.get_stat(StatId.Id.COOLDOWN_REDUCTION), 0.36, 0.0001, "1 − 0.8 × 0.8")


func test_ABL_19_skill_cooldown_shortened() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var hero: Entity = _hero(s, &"myra")
	var a: AbilityInstance = Abilities.of(hero, AbilityDef.Slot.Q)
	a.rank = 1
	var full: int = Abilities.cooldown_ticks(hero, a)
	assert_eq(full, SimClock.seconds_to_ticks(Abilities.value(hero, a, &"cooldown")))
	Items.give(w, hero, w.item_catalog[&"time_orb"])
	w.step()
	assert_eq(Abilities.cooldown_ticks(hero, a), SimClock.seconds_to_ticks(Abilities.value(hero, a, &"cooldown") * 0.8))


func test_ABL_19_item_active_cooldown_shortened() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var hero: Entity = _hero(s, &"noctis")
	Items.give(w, hero, w.item_catalog[&"time_orb"])
	Items.give(w, hero, w.item_catalog[&"shadow_blade"])
	w.step()
	var a: AbilityInstance = Abilities.of(hero, Items.SLOT_BASE + 1)
	var base_cd: float = Abilities.value(hero, a, &"cooldown")
	w.submit(Command.cast(hero.id, Items.SLOT_BASE + 1))
	w.step()
	assert_true(absi(a.ready_tick - w.tick - SimClock.seconds_to_ticks(base_cd * 0.8)) <= 1, "đồ chủ động cũng giảm 20%")


func test_CMB_13_unamplified_item_damage_ignores_spell_amp() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var hero: Entity = _hero(s, &"myra")
	var victim: Entity = _hero(s, &"brakk", Vector2(4100, 4000), 1)
	Items.give(w, hero, w.item_catalog[&"arcane_scepter"])
	w.step()
	assert_true(hero.stats.get_stat(StatId.Id.SPELL_AMPLIFICATION) > 0.3)
	var d: DamageAction = DamageAction.new()
	d.damage_type = DamageFormulas.DamageType.MAGIC
	d.amount = "70"
	d.amplified = false
	ActionRunner._damage(w, d, ExprContext.make(hero, victim), victim, hero.id)
	assert_near(w.damage_requests[0].raw, 70.0, 0.001, "không nhân khuếch đại phép")


func test_D_132_thunder_staff_adds_70_magic_on_hit_not_on_structures() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var d: ItemDef = w.item_catalog[&"thunder_staff"]
	var eff: EffectDef = (d.ability.on_learn[0] as ApplyEffectAction).effect
	var t: TriggerDef = eff.triggers[0]
	assert_eq(t.event, &"attack_landed")
	assert_eq(t.condition, &"target_not_structure")
	assert_true(t.chance.is_empty(), "mọi đòn trúng")
	var hit: DamageAction = t.actions[0]
	assert_eq(hit.damage_type, DamageFormulas.DamageType.MAGIC)
	assert_false(hit.amplified)
	assert_eq(d.ability.values[&"bonus_damage"][0], 70.0)


func test_ITM_05_chain_axe_values_by_attack_type() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var melee: Entity = _hero(s, &"brakk")
	var ranged: Entity = _hero(s, &"myra", Vector2(4300, 4000))
	Items.give(w, melee, w.item_catalog[&"chain_axe"])
	Items.give(w, ranged, w.item_catalog[&"chain_axe"])
	w.step()
	var am: AbilityInstance = Abilities.of(melee, Items.SLOT_BASE)
	var ar: AbilityInstance = Abilities.of(ranged, Items.SLOT_BASE)
	assert_near(Abilities.value(melee, am, &"chance"), 0.3, 0.0001)
	assert_near(Abilities.value(melee, am, &"bonus_damage"), 80.0, 0.0001)
	assert_near(Abilities.value(ranged, ar, &"chance"), 0.1, 0.0001)
	assert_near(Abilities.value(ranged, ar, &"bonus_damage"), 40.0, 0.0001)
	assert_near(Abilities.value(melee, am, &"root_duration"), 1.0, 0.0001)


func test_D_132_chain_axe_roots_and_hits_physical() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var eff: EffectDef = ((w.item_catalog[&"chain_axe"] as ItemDef).ability.on_learn[0] as ApplyEffectAction).effect
	var t: TriggerDef = eff.triggers[0]
	assert_eq(t.event, &"attack_landed")
	assert_eq(t.chance, "chance")
	assert_true(t.cooldown.is_empty(), "không có hồi nội tại")
	assert_ne(t.unique_group, &"bash", "tung riêng với Búa Choáng")
	var hit: DamageAction = t.actions[0]
	assert_eq(hit.damage_type, DamageFormulas.DamageType.PHYSICAL)
	var root: ApplyEffectAction = t.actions[1]
	assert_eq(root.effect.id, &"root")


func test_D_132_stat_items() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var hero: Entity = _hero(s, &"noctis")
	w.step()
	var ms: float = hero.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	Items.give(w, hero, w.item_catalog[&"twin_blades"])
	w.step()
	assert_near(hero.stats.get_stat(StatId.Id.MOVEMENT_SPEED), StatFormulas.movement_speed(hero.stats.natural(StatId.Id.MOVEMENT_SPEED) * 1.2, w.balance), 0.5, "+20% tốc chạy")
	assert_true(hero.stats.get_stat(StatId.Id.MOVEMENT_SPEED) > ms)
	Items.give(w, hero, w.item_catalog[&"focus_staff"])
	w.step()
	assert_near(hero.stats.get_stat(StatId.Id.ACCURACY), 0.75, 0.0001, "75% xuyên né")
	Items.give(w, hero, w.item_catalog[&"shadow_dance_blade"])
	w.step()
	assert_near(hero.stats.get_stat(StatId.Id.EVASION), 0.3, 0.0001)
