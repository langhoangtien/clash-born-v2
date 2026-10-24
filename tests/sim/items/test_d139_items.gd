extends TestCase
## D-139: cân bằng đồ — hút máu (CMB-05b), tầm chiêu (ABL-21), món ghép không kém thành phần,
## đồ tầm trung, dòng hút máu, né, kháng hiệu ứng.

## Món được phép đổi chỉ số thành phần sang công dụng khác (người chơi chốt).
const CONVERTS: Dictionary = {&"piercing_staff": [&"magic_armor"], &"twin_blades": [&"movement_speed"]}


func _world() -> Array:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	MatchSetup.add_shop(w, lib)
	return [w, lib]


func _sum(d: ItemDef) -> Dictionary:
	var out: Dictionary = {}
	for m: ModifierDef in d.modifiers:
		if m.op == ModifierDef.Op.ADD:
			out[m.stat] = out.get(m.stat, 0.0) + float(m.value)
	return out


func test_D_139_composites_never_lose_component_stats() -> void:
	var w: World = _world()[0]
	for d: ItemDef in w.item_catalog.values():
		if d.components.is_empty():
			continue
		var parts: Dictionary = {}
		for id: StringName in d.components:
			var p: Dictionary = _sum(w.item_catalog[id])
			for k: StringName in p:
				parts[k] = parts.get(k, 0.0) + p[k]
		var mine: Dictionary = _sum(d)
		for k: StringName in parts:
			if (CONVERTS.get(d.id, []) as Array).has(k):
				continue
			assert_true(mine.get(k, 0.0) >= parts[k] - 0.001, "%s: %s %.2f < thành phần %.2f" % [d.id, k, mine.get(k, 0.0), parts[k]])


func test_D_139_hyperstone_better_per_gold_than_claws() -> void:
	var w: World = _world()[0]
	var h: ItemDef = w.item_catalog[&"hyperstone"]
	var c: ItemDef = w.item_catalog[&"claws_fury"]
	assert_true(_sum(h)[&"attack_speed"] / h.cost > _sum(c)[&"attack_speed"] / c.cost)


func test_CMB_05b_lifesteal_heals_on_attacks_not_structures_or_skills() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var lib: ContentLibrary = s[1]
	var me: Entity = UnitFactory.hero(w, lib.heroes[&"brakk"], 0, Vector2(4000, 4000))
	var foe: Entity = UnitFactory.hero(w, lib.heroes[&"myra"], 1, Vector2(4100, 4000))
	Items.give(w, me, w.item_catalog[&"morbid_mask"])
	w.step()
	assert_near(me.stats.get_stat(StatId.Id.LIFESTEAL), 0.15, 0.0001)
	me.health = 100.0
	foe.health = 5000.0
	var r: DamageRequest = DamageRequest.attack(me, foe.id)
	r.raw = 100.0
	w.damage_requests.append(r)
	DamageSystem.resolve(w)
	var dealt: float = 5000.0 - foe.health
	assert_near(me.health - 100.0, dealt * 0.15, 0.01, "hồi 15% sát thương đòn đánh sau giáp")
	me.health = 100.0
	var spell: DamageRequest = DamageRequest.new()
	spell.source_id = me.id
	spell.target_id = foe.id
	spell.raw = 100.0
	w.damage_requests.append(spell)
	DamageSystem.resolve(w)
	assert_near(me.health, 100.0, 0.001, "sát thương chiêu không hút")


func test_D_139_satanic_active_adds_150_percent_lifesteal() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var me: Entity = UnitFactory.hero(w, (s[1] as ContentLibrary).heroes[&"brakk"], 0, Vector2(4000, 4000))
	Items.give(w, me, w.item_catalog[&"satanic"])
	w.step()
	assert_near(me.stats.get_stat(StatId.Id.LIFESTEAL), 0.25, 0.0001)
	w.submit(Command.cast(me.id, Items.SLOT_BASE))
	for i: int in range(3):
		w.step()
	assert_near(me.stats.get_stat(StatId.Id.LIFESTEAL), 1.75, 0.0001)
	for i: int in range(30 * 5 + 2):
		w.step()
	assert_near(me.stats.get_stat(StatId.Id.LIFESTEAL), 0.25, 0.0001, "hết 5 s")


func test_ABL_21_storm_staff_extends_cast_range() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var me: Entity = UnitFactory.hero(w, (s[1] as ContentLibrary).heroes[&"gorran"], 0, Vector2(4000, 4000))
	var a: AbilityInstance = Abilities.of(me, AbilityDef.Slot.W)
	a.rank = 1
	var reach: float = Abilities.value(me, a, &"cast_range")
	Items.give(w, me, w.item_catalog[&"storm_staff"])
	w.step()
	assert_near(Abilities.value(me, a, &"cast_range"), reach + 200.0, 0.001, "+200 tầm chiêu")


func test_D_139_new_items_stats() -> void:
	var w: World = _world()[0]
	assert_eq(_sum(w.item_catalog[&"sage_cloak"])[&"magic_armor"], 12.0)
	assert_eq(_sum(w.item_catalog[&"mirage_orb"])[&"evasion"], 0.2)
	assert_eq(_sum(w.item_catalog[&"steadfast_armor"])[&"status_resistance"], 0.2)
	assert_eq(_sum(w.item_catalog[&"steadfast_armor"])[&"physical_armor"], 15.0)
	assert_true(w.item_catalog[&"shadow_dance_blade"].components.has(&"mirage_orb"), "kiếm né ghép từ món né")
	for id: StringName in [&"reaver", &"eaglesong", &"mystic_staff", &"sacred_relic"]:
		var used: bool = false
		for d: ItemDef in w.item_catalog.values():
			used = used or d.components.has(id)
		assert_true(used, "%s được dùng để ghép" % id)
