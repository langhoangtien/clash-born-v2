extends TestCase
## D-141: Tim Khổng Lồ hồi % máu, tạm dừng khi bị tướng đánh (EFF-17); kéo dài hiệu ứng gây ra
## (ST-09b); đồ hồi phục tầm trung; Ngọc Băng Sương II / Cánh Bướm công thức mới.


func _world() -> Array:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	MatchSetup.add_shop(w, lib)
	var me: Entity = UnitFactory.hero(w, lib.heroes[&"brakk"], 0, Vector2(4000, 4000))
	var foe: Entity = UnitFactory.hero(w, lib.heroes[&"myra"], 1, Vector2(4100, 4000))
	return [w, me, foe, lib]


func test_D_142_heart_regen_max_plus_missing_hp() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var me: Entity = s[1]
	Items.give(w, me, w.item_catalog[&"giant_heart"])
	w.step()
	var max_hp: float = me.stats.get_stat(StatId.Id.MAX_HP)
	var regen: float = me.stats.get_stat(StatId.Id.HP_REGEN)
	me.health = max_hp * 0.2
	var before: float = me.health
	for i: int in range(6):
		w.step()  # 0.2 s một nhịp
	var missing: float = max_hp - before
	assert_near(me.health - before, 0.2 * (0.01 * max_hp + 0.015 * missing) + regen * 0.2, 3.0, "0.2 s: 1% tối đa + 1.5% đã mất mỗi giây")
	me.health = max_hp
	for i: int in range(30):
		w.step()
	assert_near(me.health, max_hp, 0.001, "đầy thì không vượt")


func test_D_142_orchid_silences_enemy_hero() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var me: Entity = s[1]
	var foe: Entity = s[2]
	Items.give(w, me, w.item_catalog[&"orchid"])
	me.mana = 1000.0
	w.step()
	w.submit(Command.cast(me.id, Items.SLOT_BASE, foe.id))
	for i: int in range(3):
		w.step()
	assert_true(Rules.has_state(foe, UnitState.Id.SILENCED), "câm lặng")
	for i: int in range(30 * 4 + 2):
		w.step()
	assert_false(Rules.has_state(foe, UnitState.Id.SILENCED), "hết 4 s")


func test_ST_09b_fate_staff_extends_debuffs_it_applies() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var me: Entity = s[1]
	var foe: Entity = s[2]
	var lib: ContentLibrary = s[3]
	Items.give(w, me, w.item_catalog[&"fate_staff"])
	w.step()
	var inst: EffectInstance = Effects.apply(w, foe, lib.effects[&"stun"], me, {}, "2")
	assert_eq(inst.end_tick - inst.start_tick, SimClock.seconds_to_ticks(2.5), "2 s × 1.25")
	var self_buff: EffectInstance = Effects.apply(w, me, lib.effects[&"stun"], me, {}, "2")
	assert_eq(self_buff.end_tick - self_buff.start_tick, SimClock.seconds_to_ticks(2.0), "chỉ hiệu ứng lên địch")


func test_D_141_recipes_and_stats() -> void:
	var w: World = _world()[0]
	var c: Dictionary = w.item_catalog
	assert_eq(c[&"frost_orb_ii"].components, [&"frost_orb", &"vitality_booster", &"circlet"] as Array[StringName])
	assert_true(c[&"butterfly"].components.has(&"evasion_charm"), "Cánh Bướm ghép từ Bùa Né Tránh")
	assert_false(c[&"butterfly"].components.has(&"blade_alacrity"))
	assert_eq(c[&"perseverance"].components, [&"ring_health", &"void_stone"] as Array[StringName])
	var sages: int = 0
	for d: ItemDef in c.values():
		sages += d.components.count(&"sages_mask")
	assert_true(sages <= 2, "Mặt Nạ Hiền Triết bớt bị dùng (%d)" % sages)
	var as_boots: float = 0.0
	for m: ModifierDef in c[&"boots_haste"].modifiers:
		if m.stat == &"attack_speed":
			as_boots = float(m.value)
	assert_near(as_boots, 0.35, 0.0001)
