extends TestCase
## D-121: đồ đẩy trụ — Lưỡi Hái Hủy Diệt giảm giáp cả trụ, Mảnh Trăng tốc đánh.

const MAP_PATH: String = "res://data/maps/clashborn.tres"


func _world() -> Array:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	w.map = load(MAP_PATH) as MapLayout
	MatchSetup.spawn_structures(w, lib)
	MatchSetup.add_shop(w, lib)
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return [w, lib]


func test_D_121_desolator_attack_lowers_tower_armor() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var lib: ContentLibrary = s[1]
	var tower: Entity = Objectives.next_for_lane(w, 0, "MID")
	tower.locked = false
	var hero: Entity = UnitFactory.hero(w, lib.heroes[&"noctis"], 0, tower.position + Vector2(-200, 200))
	Items.give(w, hero, w.item_catalog[&"desolator"])
	var armor: float = tower.stats.get_stat(StatId.Id.PHYSICAL_ARMOR)
	w.submit(Command.attack(hero.id, tower.id))
	for i: int in range(60):
		w.step()
	assert_near(tower.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), armor - 6.0, 0.01, "đòn đánh giảm 6 giáp của trụ")


func test_D_121_moon_shard_built_from_hyperstone_and_claws() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var lib: ContentLibrary = s[1]
	var hero: Entity = UnitFactory.hero(w, lib.heroes[&"noctis"], 0, Vector2(1000, 1000))
	var before: float = hero.stats.get_stat(StatId.Id.ATTACK_SPEED)
	Items.give(w, hero, w.item_catalog[&"moon_shard"])
	w.step()
	assert_near(hero.stats.get_stat(StatId.Id.ATTACK_SPEED) - before, 1.5, 0.001)
	assert_eq((w.item_catalog[&"moon_shard"] as ItemDef).components, [&"hyperstone", &"claws_fury"] as Array[StringName])


func test_CMB_04b_tower_hits_lane_creep_for_60_percent() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var lib: ContentLibrary = s[1]
	var tower: Entity = Objectives.next_for_lane(w, 0, "MID")
	var creep: Entity = MatchSetup.spawn_creep(w, lib, &"creep_melee", 0, "MID", tower.position + Vector2(-150, 150))
	var hero: Entity = UnitFactory.hero(w, lib.heroes[&"brakk"], 0, tower.position + Vector2(150, -150))
	assert_near(DamageSystem._structure_factor(w, tower, creep), 0.6, 0.0001, "trụ lên lính: 60%")
	assert_near(DamageSystem._structure_factor(w, tower, hero), 1.0, 0.0001, "trụ lên hero: giữ nguyên")


func test_D_125_mana_potion_restores_100_mana_over_20s() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var lib: ContentLibrary = s[1]
	var hero: Entity = UnitFactory.hero(w, lib.heroes[&"myra"], 0, w.map.world_size() * 0.5)  # xa fountain
	Items.give(w, hero, w.item_catalog[&"mana_potion"])
	w.step()
	hero.mana = 0.0
	var regen: float = hero.stats.get_stat(StatId.Id.MANA_REGEN)
	w.submit(Command.cast(hero.id, Items.SLOT_BASE + 0))
	for i: int in range(30 * 20 + 5):
		w.step()
	assert_near(hero.mana - regen * 20.0, 100.0, 3.0, "bình mana: +100 trong 20 s")
	assert_eq(Items.slots(hero)[0], null, "dùng một lần: hết bình")


func test_CMB_13_intelligence_and_items_amplify_spell_damage_not_attacks() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var lib: ContentLibrary = s[1]
	var hero: Entity = UnitFactory.hero(w, lib.heroes[&"myra"], 0, w.map.world_size() * 0.5)
	w.step()
	var intel: float = hero.stats.get_stat(StatId.Id.INTELLIGENCE)
	assert_near(hero.stats.get_stat(StatId.Id.SPELL_AMPLIFICATION), intel * 0.003, 0.0001, "mỗi Trí tuệ +0.3%")
	Items.give(w, hero, w.item_catalog[&"arcane_scepter"])
	w.step()
	var amp: float = hero.stats.get_stat(StatId.Id.SPELL_AMPLIFICATION)
	assert_near(amp, (intel + 30.0) * 0.003 + 0.30, 0.0001, "Quyền Trượng: +30 Trí tuệ, +30%")
	var foe: Entity = UnitFactory.hero(w, lib.heroes[&"brakk"], 1, hero.position + Vector2(200, 0))
	var d: DamageAction = DamageAction.new()
	d.damage_type = DamageFormulas.DamageType.PURE
	d.amount = "100"
	var ctx: ExprContext = ExprContext.new()
	ctx.owner = hero
	ActionRunner._damage(w, d, ctx, foe, hero.id)
	assert_near((w.damage_requests[-1] as DamageRequest).raw, 100.0 * (1.0 + amp), 0.001, "sát thương chiêu nhân khuếch đại")
	assert_eq((w.item_catalog[&"arcane_scepter"] as ItemDef).components, [&"ancient_tome", &"staff_wizardry", &"sages_mask"] as Array[StringName])
