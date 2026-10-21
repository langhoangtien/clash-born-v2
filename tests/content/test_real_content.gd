extends TestCase
## M0.6: dữ liệu thật trong content/ khớp CONTENT.md và sạch lỗi.

static var _lib: ContentLibrary


func before_each() -> void:
	if _lib == null:
		_lib = ContentLibrary.load_dir()


func _v(ability: AbilityDef, value_name: String) -> PackedFloat32Array:
	return ability.values.get(StringName(value_name), PackedFloat32Array())


func test_content_has_no_errors() -> void:
	var errs: PackedStringArray = ContentValidator.errors(_lib)
	assert_true(errs.is_empty(), "\n".join(errs))


func test_four_heroes_and_items() -> void:
	assert_eq(_lib.heroes.keys().map(func(k: StringName) -> String: return String(k)).size(), 4)
	for id: StringName in [&"brakk", &"myra", &"noctis", &"vexa"]:
		assert_true(_lib.heroes.has(id), "có hero " + id)
	for id: StringName in [&"ghost_scepter", &"resolute_armor", &"frost_orb", &"reveal_dust", &"cyclone_staff",
			&"shadow_blade", &"hex_scythe", &"cleansing_charm", &"stun_hammer"]:
		assert_true(_lib.items.has(id), "có đồ " + id)
	assert_true(_lib.items.size() >= 50, "D-106: đồ cơ bản + đồ ghép kiểu Dota")
	for d: ItemDef in _lib.items.values():  # SHOP-09: thành phần có thật, phí ghép không âm
		var sum: int = 0
		for c: StringName in d.components:
			assert_true(_lib.items.has(c), "%s ghép từ món không có: %s" % [d.id, c])
			sum += _lib.items[c].cost if _lib.items.has(c) else 0
		assert_true(d.cost >= sum, "%s: giá ≥ tổng thành phần" % d.id)
	for h: HeroDef in _lib.heroes.values():
		for id: StringName in h.bot_item_build:
			assert_true(_lib.items.has(id), "lên đồ bot %s: %s" % [h.id, id])
	var C := ItemDef.Category
	var table: Dictionary = {  # SHOP-07, D-90: danh mục, shop ẩn, giờ mở (s), độc nhất
		&"stun_hammer": [C.ATTACK, false, 0, false], &"shadow_blade": [C.ATTACK, false, 0, false],
		&"ghost_scepter": [C.MAGIC, false, 0, false], &"cyclone_staff": [C.MAGIC, false, 0, false],
		&"hex_scythe": [C.MAGIC, false, 900, true], &"cleansing_charm": [C.DEFENSE, false, 0, false],
		&"frost_orb": [C.DEFENSE, true, 0, false], &"resolute_armor": [C.DEFENSE, true, 600, false],
		&"reveal_dust": [C.UTILITY, false, 0, false],
		&"observer_ward": [C.UTILITY, false, 0, false], &"sentry_ward": [C.UTILITY, false, 0, false],
	}
	for id: StringName in table:
		var d: ItemDef = _lib.items[id]
		var row: Array = table[id]
		assert_eq(d.category, row[0], "danh mục " + id)
		assert_eq(d.shop == ItemDef.ShopKind.SECRET, row[1], "shop ẩn " + id)
		assert_near(d.unlock_time, row[2], 0.01, "giờ mở " + id)
		assert_eq(d.unique, row[3], "độc nhất " + id)
		assert_true(d.description.length() > 20, "có mô tả " + id)


func test_D_35_heroes_grow_only_attributes() -> void:
	var brakk: HeroDef = _lib.heroes[&"brakk"]
	assert_eq(brakk.primary_attribute, StatFormulas.Attribute.STRENGTH)
	assert_near(brakk.strength_growth, 3.8, 0.0001)
	assert_near(brakk.stats.base_damage, 74.0, 0.0001)


func test_CONTENT_brakk_numbers() -> void:
	var brakk: HeroDef = _lib.heroes[&"brakk"]
	assert_near(_v(brakk.q, "damage")[4], 230.0, 0.001, "Q cấp 5 gây 230")
	assert_near(_v(brakk.innate, "chance")[5], 0.25, 0.0001, "bash bậc 6 = 25%")
	assert_eq(_v(brakk.r, "cooldown"), PackedFloat32Array([90, 80, 70]))


func test_CONTENT_myra_numbers() -> void:
	var myra: HeroDef = _lib.heroes[&"myra"]
	assert_eq(_v(myra.r, "cooldown"), PackedFloat32Array([80, 70, 60]))
	assert_near(_v(myra.w, "delay")[0], 0.8, 0.0001)
	assert_eq(myra.stats.attack_range, 550.0)


func test_CONTENT_noctis_and_vexa_numbers() -> void:
	var noctis: HeroDef = _lib.heroes[&"noctis"]
	assert_near(_v(noctis.innate, "crit_multiplier")[5], 2.6, 0.0001)
	var vexa: HeroDef = _lib.heroes[&"vexa"]
	assert_true(vexa.r.pierces_magic_immunity, "Vexa R xuyên miễn phép (ST-15)")
	assert_eq(_v(vexa.w, "length")[0], 700.0)


func test_STAT_05_brakk_bash_and_stun_hammer_share_group() -> void:
	var brakk_passive: EffectDef = _lib.effects[&"brakk_bash_passive"]
	var hammer_passive: EffectDef = _lib.effects[&"stun_hammer_passive"]
	assert_eq(brakk_passive.triggers[0].unique_group, &"bash")
	assert_eq(hammer_passive.triggers[0].unique_group, &"bash")


func test_ITM_05_stun_hammer_melee_ranged_chances() -> void:
	var hammer: ItemDef = _lib.items[&"stun_hammer"]
	assert_near(_v(hammer.ability, "chance_melee")[0], 0.2, 0.0001)
	assert_near(_v(hammer.ability, "chance_ranged")[0], 0.1, 0.0001)


func test_every_ability_has_art_id() -> void:
	for id: StringName in _lib.heroes:
		var hero: HeroDef = _lib.heroes[id]
		assert_false(hero.art_id.is_empty(), String(id))
		for ability: AbilityDef in hero.abilities():
			assert_false(ability.art_id.is_empty(), String(ability.id))


## Máu và giáp cấp 1 (đã tính thuộc tính) theo khung trong CONTENT.md (D-39).
const LEVEL1_RANGES: Dictionary = {
	StatFormulas.Attribute.STRENGTH: [500.0, 700.0, 1.0, 5.0],
	StatFormulas.Attribute.AGILITY: [400.0, 600.0, 2.0, 7.0],
	StatFormulas.Attribute.INTELLIGENCE: [400.0, 600.0, 1.0, 4.0],
}


func _level1(hero: HeroDef) -> StatBlock:
	var b: StatBlock = StatBlock.new(load("res://content/balance/balance_settings.tres"))
	b.set_base(StatId.Id.MAX_HP, hero.stats.base_hp)
	b.set_base(StatId.Id.PHYSICAL_ARMOR, hero.stats.physical_armor)
	b.set_base(StatId.Id.MAGIC_ARMOR, hero.stats.magic_armor)
	b.set_base(StatId.Id.BASE_ATTACK_TIME, hero.stats.base_attack_time)
	b.set_attributes(hero.primary_attribute, Vector3(hero.base_strength, hero.base_agility, hero.base_intelligence),
		Vector3(hero.strength_growth, hero.agility_growth, hero.intelligence_growth))
	b.set_level(1, 0, 2.0)
	b.recompute()
	return b


func test_D_39_level1_hp_and_armor_in_design_range() -> void:
	for id: StringName in _lib.heroes:
		var hero: HeroDef = _lib.heroes[id]
		var r: Array = LEVEL1_RANGES[hero.primary_attribute]
		var b: StatBlock = _level1(hero)
		var hp: float = b.get_stat(StatId.Id.MAX_HP)
		var armor: float = b.get_stat(StatId.Id.PHYSICAL_ARMOR)
		assert_true(hp >= r[0] and hp <= r[1], "%s máu cấp 1 = %.0f, cần %s–%s" % [id, hp, r[0], r[1]])
		assert_true(armor >= r[2] and armor <= r[3], "%s giáp cấp 1 = %.2f, cần %s–%s" % [id, armor, r[2], r[3]])


func test_STAT_04_intelligence_gives_magic_armor_like_agility_gives_armor() -> void:
	var bal: BalanceSettings = load("res://content/balance/balance_settings.tres")
	assert_eq(bal.magic_armor_per_intelligence, bal.armor_per_agility)
	var b: StatBlock = _level1(_lib.heroes[&"myra"])
	assert_near(b.get_stat(StatId.Id.MAGIC_ARMOR), 30 * bal.magic_armor_per_intelligence, 0.0001)


func test_EFF_03_slows_from_different_sources_stack() -> void:
	for id: StringName in [&"myra_frost_slow", &"vexa_purge_slow", &"frost_orb_slow"]:
		var e: EffectDef = _lib.effects[id]
		assert_true(e.modifiers[0].unique_group.is_empty(), "%s không thuộc nhóm duy nhất" % id)


func test_minimum_movement_speed_is_zero() -> void:
	var bal: BalanceSettings = load("res://content/balance/balance_settings.tres")
	assert_eq(bal.minimum_movement_speed, 0.0)
