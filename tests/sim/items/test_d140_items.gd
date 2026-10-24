extends TestCase
## D-140: Giáp Thép phản sát thương, Giáp Bất Khuất giảm sát thương vật lý (CMB-16), Trượng Hắc Vương.


func _world() -> Array:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	MatchSetup.add_shop(w, lib)
	var me: Entity = UnitFactory.hero(w, lib.heroes[&"brakk"], 0, Vector2(4000, 4000))
	var foe: Entity = UnitFactory.hero(w, lib.heroes[&"noctis"], 1, Vector2(4100, 4000))
	me.health = 5000.0
	foe.health = 5000.0
	return [w, me, foe, lib]


func _hit(w: World, from: Entity, to: Entity, raw: float, attack: bool = true) -> float:
	var r: DamageRequest = DamageRequest.attack(from, to.id) if attack else DamageRequest.new()
	r.source_id = from.id
	r.target_id = to.id
	r.raw = raw
	w.damage_requests.append(r)
	var before: float = to.health
	DamageSystem.resolve(w)
	return before - to.health


func test_CMB_16_resolute_armor_cuts_physical_10_percent() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var me: Entity = s[1]
	var foe: Entity = s[2]
	Items.give(w, me, w.item_catalog[&"resolute_armor"])
	w.step()
	assert_near(me.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE_REDUCTION), 0.1, 0.0001)
	var mult: float = DamageFormulas.armor_multiplier(me.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), w.balance.armor_coefficient)
	me.health = 5000.0
	assert_near(_hit(w, foe, me, 100.0, false), 100.0 * mult * 0.9, 0.01, "vật lý −10% sau giáp")
	var r: DamageRequest = DamageRequest.new()
	r.source_id = foe.id
	r.target_id = me.id
	r.raw = 100.0
	r.damage_type = DamageFormulas.DamageType.MAGIC
	w.damage_requests.append(r)
	var before: float = me.health
	DamageSystem.resolve(w)
	var mmult: float = DamageFormulas.armor_multiplier(me.stats.get_stat(StatId.Id.MAGIC_ARMOR), w.balance.armor_coefficient)
	assert_near(before - me.health, 100.0 * mmult, 0.01, "phép không giảm")


func test_CMB_16_two_sources_multiply() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var me: Entity = s[1]
	Items.give(w, me, w.item_catalog[&"resolute_armor"])
	Items.give(w, me, w.item_catalog[&"resolute_armor"])
	w.step()
	assert_near(me.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE_REDUCTION), 0.19, 0.0001, "1 − 0.9 × 0.9")


func test_D_140_steel_armor_returns_20_plus_20_percent_to_heroes() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var me: Entity = s[1]
	var foe: Entity = s[2]
	Items.give(w, me, w.item_catalog[&"steel_armor"])
	w.step()
	me.health = 5000.0
	foe.health = 5000.0
	var taken: float = _hit(w, foe, me, 100.0)
	TriggerSystem.new().run(w)  # pha TRIGGER của tick này
	var back: float = 5000.0 - foe.health
	var fmult: float = DamageFormulas.armor_multiplier(foe.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), w.balance.armor_coefficient)
	assert_near(back, (20.0 + 0.2 * taken) * fmult, 0.5, "20 + 20% đòn nhận, giáp kẻ đánh áp")
	assert_eq((w.item_catalog[&"steel_armor"] as ItemDef).components, [&"chainmail", &"ring_protection", &"broadsword"] as Array[StringName])


func test_D_140_black_king_bar_keeps_old_active() -> void:
	var w: World = _world()[0]
	var d: ItemDef = w.item_catalog[&"black_king_bar"]
	assert_true(d.ability != null and d.ability.targeting == AbilityDef.Targeting.NO_TARGET)
	assert_true(w.item_catalog[&"resolute_armor"].ability == null, "Giáp Bất Khuất không còn chủ động")
