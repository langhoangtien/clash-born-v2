extends TestCase
## STAT-07 (D-382): modifier có điều kiện kiểu đánh; Thương Rồng (+tầm đánh chỉ tướng đánh xa).

const F = preload("res://tests/content/fixture_content.gd")


func _world() -> Array:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	MatchSetup.add_shop(w, lib)
	var melee: Entity = UnitFactory.hero(w, lib.heroes[&"brakk"], 0, Vector2(4000, 4000))
	var ranged: Entity = UnitFactory.hero(w, lib.heroes[&"myra"], 0, Vector2(4200, 4000))
	return [w, melee, ranged]


func _range_mod(condition: StringName) -> ModifierDef:
	var m: ModifierDef = ModifierDef.new()
	m.stat = &"attack_range"
	m.value = "100"
	m.condition = condition
	return m


func _effect(mods: Array[ModifierDef]) -> EffectDef:
	var d: EffectDef = EffectDef.new()
	d.id = &"test_stat_07"
	d.duration = "0"
	d.modifiers = mods
	return d


## Chỉ số được tính lại ở pha STATE; test đọc ngay sau khi áp thì tính lại trước.
func _stat(e: Entity, id: StatId.Id) -> float:
	e.stats.recompute()
	return e.stats.get_stat(id)


func _range(e: Entity) -> float:
	return _stat(e, StatId.Id.ATTACK_RANGE)


func test_STAT_07_ranged_only_modifier_applies_to_ranged() -> void:
	var s: Array = _world()
	var before: float = _range(s[2])
	Effects.apply(s[0], s[2], _effect([_range_mod(&"owner_is_ranged")] as Array[ModifierDef]), s[2])
	assert_near(_range(s[2]), before + 100.0, 0.001)


func test_STAT_07_ranged_only_modifier_skipped_for_melee() -> void:
	var s: Array = _world()
	var before: float = _range(s[1])
	Effects.apply(s[0], s[1], _effect([_range_mod(&"owner_is_ranged")] as Array[ModifierDef]), s[1])
	assert_near(_range(s[1]), before, 0.001)


func test_STAT_07_melee_only_modifier_mirrors() -> void:
	var s: Array = _world()
	var melee_before: float = _range(s[1])
	var ranged_before: float = _range(s[2])
	var d: EffectDef = _effect([_range_mod(&"owner_is_melee")] as Array[ModifierDef])
	Effects.apply(s[0], s[1], d, s[1])
	Effects.apply(s[0], s[2], d, s[2])
	assert_near(_range(s[1]), melee_before + 100.0, 0.001)
	assert_near(_range(s[2]), ranged_before, 0.001)


func test_STAT_07_other_modifiers_of_item_still_apply() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var melee: Entity = s[1]
	var before: Array[float] = [_stat(melee, StatId.Id.STRENGTH), _stat(melee, StatId.Id.AGILITY), _range(melee)]
	Items.give(w, melee, w.item_catalog[&"dragon_lance"])
	assert_near(_stat(melee, StatId.Id.STRENGTH), before[0] + 10.0, 0.001, "tướng cận vẫn nhận STR")
	assert_near(_stat(melee, StatId.Id.AGILITY), before[1] + 12.0, 0.001, "tướng cận vẫn nhận AGI")
	assert_near(_range(melee), before[2], 0.001, "tướng cận không nhận tầm")


func test_ITM_dragon_lance_range_only_for_ranged() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var ranged: Entity = s[2]
	var before: float = _range(ranged)
	Items.give(w, ranged, w.item_catalog[&"dragon_lance"])
	assert_near(_range(ranged), before + 140.0, 0.001, "T1: +140 tầm đánh")
	var d: ItemDef = w.item_catalog[&"dragon_lance"]
	assert_eq(d.cost, 1900, "T1: ~1900 vàng")
	assert_eq(d.components, [&"ogre_axe", &"blade_alacrity"] as Array[StringName])


func test_STAT_07_unknown_condition_rejected_by_validator() -> void:
	var it: ItemDef = F.item()
	it.modifiers = [_range_mod(&"owner_is_flying")] as Array[ModifierDef]
	var errs: String = "\n".join(ContentValidator.errors(F.library_with([it] as Array[GameDef])))
	assert_true(errs.contains("STAT-07"), "cần lỗi STAT-07, có: %s" % errs)
