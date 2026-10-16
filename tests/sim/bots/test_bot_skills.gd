extends TestCase
## M7.4: bot dùng chiêu / đồ theo bot_usage (BOT-13..15), nâng điểm, chọn talent (BOT-14),
## mua đồ, shop ẩn, cắm mắt vàng, độ khó (D-94).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const Mode := BotState.Mode
const S := AbilityDef.Slot

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.spawn_structures(w, _lib)
	MatchSetup.add_vision(w)
	MatchSetup.add_shop(w, _lib)
	return w


func _mid() -> Vector2:
	return _map.world_size() * 0.5


func _dir() -> Vector2:
	return (_map.fountain_point(1) - _map.fountain_point(0)).normalized()


func _bot(w: World, id: StringName, at: Vector2, ranks: Array[int] = [1, 1, 1]) -> Entity:
	var e: Entity = UnitFactory.hero(w, _lib.heroes[id], 1, w.navigation(32.0).nearest_clear(at), 6)
	MatchSetup.add_bot(w, e)
	e.skill_points = 0
	for i: int in range(3):
		Abilities.set_rank(w, e, Abilities.of(e, [S.Q, S.W, S.R][i]), ranks[i])
	return e


func _foe(w: World, at: Vector2, id: StringName = &"brakk") -> Entity:
	return UnitFactory.hero(w, _lib.heroes[id], 0, w.navigation(32.0).nearest_clear(at), 6)


func _cast_slots(w: World, e: Entity, ticks: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in range(ticks):
		w.step()
		for ev: GameEvent in w.events:
			if ev.type == &"ability_cast" and ev.source_id == e.id:
				out.append(int(ev.amount))
	return out


func _on_cooldown(w: World, e: Entity, slot: int) -> bool:
	return Abilities.of(e, slot).ready_tick > w.tick


func test_BOT_14_levels_up_by_order_and_picks_talent() -> void:
	var w: World = _world()
	var e: Entity = UnitFactory.hero(w, _lib.heroes[&"myra"], 1, _map.fountain_point(1), 3)
	MatchSetup.add_bot(w, e)
	e.skill_points = 3
	for i: int in range(40):
		w.step()
	assert_eq(e.skill_points, 0)
	assert_eq([Abilities.of(e, S.Q).rank, Abilities.of(e, S.W).rank], [2, 1], "myra: Q, W, Q")
	Progression.add_xp(w, e, 999999.0)
	for i: int in range(200):
		w.step()
	assert_eq(e.talent_slot, _lib.heroes[&"myra"].bot_talent_priority[0], "talent theo thứ tự ưu tiên")


func test_BOT_13_disable_brakk_q_when_enemy_in_radius() -> void:
	var w: World = _world()
	var e: Entity = _bot(w, &"brakk", _mid())
	_foe(w, _mid() - _dir() * 200.0)
	_cast_slots(w, e, 20)
	assert_true(_on_cooldown(w, e, S.Q), "DISABLE: hero địch trong bán kính → Q")


func test_BOT_13_poke_myra_q_with_mana_only() -> void:
	var w: World = _world()
	var e: Entity = _bot(w, &"myra", _mid())
	_foe(w, _mid() - _dir() * 800.0)
	_cast_slots(w, e, 20)
	assert_true(_on_cooldown(w, e, S.Q), "POKE: trong tầm, đủ mana")
	var g: World = _world()
	var lean: Entity = _bot(g, &"myra", _mid())
	lean.mana = lean.stats.get_stat(StatId.Id.MAX_MANA) * 0.2
	_foe(g, _mid() - _dir() * 800.0)
	_cast_slots(g, lean, 20)
	assert_false(_on_cooldown(g, lean, S.Q), "POKE: giữ mana khi còn ít")


func test_BOT_15_escape_brakk_r_when_low() -> void:
	var w: World = _world()
	var e: Entity = _bot(w, &"brakk", _mid())
	e.health = e.stats.get_stat(StatId.Id.MAX_HP) * 0.2
	_cast_slots(w, e, 20)
	assert_true(_on_cooldown(w, e, S.R), "ESCAPE: máu thấp → R bất kể an toàn")


func test_BOT_13_self_defense_brakk_w_when_hurt() -> void:
	var w: World = _world()
	var e: Entity = _bot(w, &"brakk", _mid() + _dir() * 600.0)
	var foe: Entity = _foe(w, _mid() + _dir() * 1500.0, &"myra")
	e.health = e.stats.get_stat(StatId.Id.MAX_HP) * 0.6
	_cast_slots(w, e, 12)
	assert_false(_on_cooldown(w, e, S.W), "chưa bị đánh thì chưa dùng khiên")
	var r: DamageRequest = DamageRequest.new()
	r.source_id = foe.id
	r.target_id = e.id
	r.raw = 10.0
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)
	_cast_slots(w, e, 12)
	assert_true(_on_cooldown(w, e, S.W), "SELF_DEFENSE: máu < 70% và đang nhận sát thương")


func test_BOT_15_engage_noctis_q_only_when_hunting_safely() -> void:
	var w: World = _world()
	var e: Entity = _bot(w, &"noctis", _mid() + _dir() * 600.0)
	var foe: Entity = _foe(w, _mid() + _dir() * 50.0)
	foe.health = foe.stats.get_stat(StatId.Id.MAX_HP) * 0.3
	_cast_slots(w, e, 90)
	assert_true(_on_cooldown(w, e, S.Q), "ENGAGE: đang săn, mục tiêu < 50%, đích an toàn")


func test_BOT_13_item_cleansing_charm_when_hurt_by_debuff() -> void:
	var w: World = _world()
	var e: Entity = _bot(w, &"myra", _mid() + _dir() * 600.0)
	var foe: Entity = _foe(w, _mid() + _dir() * 2000.0)
	var slot: int = Items.give(w, e, _lib.items[&"cleansing_charm"])
	Effects.apply(w, e, _lib.effects[&"silence"], foe, {}, "5")
	var r: DamageRequest = DamageRequest.new()
	r.source_id = foe.id
	r.target_id = e.id
	r.raw = 10.0
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)
	_cast_slots(w, e, 15)
	assert_false(e.effects.any(func(i: EffectInstance) -> bool: return i.def.id == &"silence"), "đồ tự thanh tẩy")
	assert_true(_on_cooldown(w, e, Items.SLOT_BASE + slot))


func test_D_94_buys_build_in_order_and_goes_to_secret_shop() -> void:
	var w: World = _world()
	var e: Entity = _bot(w, &"brakk", _map.fountain_point(1) + (_mid() - _map.fountain_point(1)).normalized() * 800.0)
	e.gold = 3000
	for i: int in range(15):
		w.step()
	assert_true(Items.slots(e)[0] != null and Items.slots(e)[0].def.id == &"stun_hammer", "món đầu trong thứ tự lên đồ")
	e.gold = 2300
	var shopping: bool = false
	for i: int in range(20):
		w.step()
		shopping = shopping or e.bot.mode == Mode.SHOP
	assert_true(shopping or Items.slots(e).any(func(it: ItemInstance) -> bool: return it != null and it.def.id == &"frost_orb"),
		"Ngọc Băng Sương ở shop ẩn: đi tới shop (hoặc đã ở gần và mua)")


func test_D_94_places_observer_at_ward_spot() -> void:
	var w: World = _world()
	var spots: Array[Vector2] = BotController.ward_spots(w, 1)
	assert_eq(spots.size(), 2, "2 điểm cắm mắt định sẵn")
	var e: Entity = _bot(w, &"myra", spots[0] + (_map.fountain_point(1) - spots[0]).normalized() * 600.0)
	e.gold = 0
	Items.give(w, e, _lib.items[&"observer_ward"])
	var placed: Entity = null
	for i: int in range(20 * 30):
		w.step()
		for o: Entity in w.entities:
			if o.kind == Entity.Kind.WARD and o.team == 1:
				placed = o
		if placed != null:
			break
	assert_true(placed != null, "bot cắm mắt vàng")
	assert_true(placed.position.distance_to(spots[0]) < 150.0 or placed.position.distance_to(spots[1]) < 150.0)


func test_D_94_difficulty_reaction_and_aim() -> void:
	var b: BotState = BotState.new()
	b.difficulty = BotState.Difficulty.EASY
	var easy: int = b.think_ticks()
	b.difficulty = BotState.Difficulty.HARD
	assert_true(b.think_ticks() < easy, "Khó phản xạ nhanh hơn")
	var w: World = _world()
	var e: Entity = _bot(w, &"myra", _mid())
	var foe: Entity = _foe(w, _mid() - _dir() * 600.0)
	e.bot.difficulty = BotState.Difficulty.HARD
	assert_eq(BotSkills.aim_point(w, e, foe), foe.position, "Khó, mục tiêu đứng yên: nhắm trúng tâm")
	e.bot.difficulty = BotState.Difficulty.EASY
	assert_true(BotSkills.aim_point(w, e, foe) != foe.position, "Dễ: lệch")
