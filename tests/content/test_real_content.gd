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


func test_four_heroes_and_nine_items() -> void:
	assert_eq(_lib.heroes.keys().map(func(k: StringName) -> String: return String(k)).size(), 4)
	for id: StringName in [&"brakk", &"myra", &"noctis", &"vexa"]:
		assert_true(_lib.heroes.has(id), "có hero " + id)
	for id: StringName in [&"ghost_scepter", &"resolute_armor", &"frost_orb", &"reveal_dust", &"cyclone_staff",
			&"shadow_blade", &"hex_scythe", &"cleansing_charm", &"stun_hammer"]:
		assert_true(_lib.items.has(id), "có đồ " + id)
	assert_eq(_lib.items.size(), 9)


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


func test_EFF_03_all_slows_share_slow_group() -> void:
	for id: StringName in [&"myra_frost_slow", &"vexa_purge_slow", &"frost_orb_slow"]:
		var e: EffectDef = _lib.effects[id]
		assert_eq(e.modifiers[0].unique_group, &"slow", String(id))


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
