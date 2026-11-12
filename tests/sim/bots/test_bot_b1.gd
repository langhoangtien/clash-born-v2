extends TestCase
## B1 (D-392, D-393): điều kiện bot `attacked_by_enemy_hero` (BOT-13) và luật BOT-23 (không đứng trước lính địch khi không
## có lính đỡ).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const Mode := BotState.Mode
const S := AbilityDef.Slot

static var _map: MapLayout
static var _lib: ContentLibrary


func _world(creeps: bool) -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.spawn_structures(w, _lib)
	MatchSetup.add_vision(w)
	if creeps:
		MatchSetup.add_lane_creeps(w, _lib, false)
	return w


func _mid() -> Vector2:
	return _map.world_size() * 0.5


func _dir() -> Vector2:
	return (_map.fountain_point(1) - _map.fountain_point(0)).normalized()


func _hero(w: World, team: int, id: StringName, at: Vector2) -> Entity:
	return UnitFactory.hero(w, _lib.heroes[id], team, w.navigation(32.0).nearest_clear(at), 6)


func _bot(w: World, id: StringName, at: Vector2) -> Entity:
	var e: Entity = _hero(w, 1, id, at)
	MatchSetup.add_bot(w, e)
	e.bot.lane = "MID"
	return e


func _creep(w: World, team: int, at: Vector2) -> Entity:
	return MatchSetup.spawn_creep(w, _lib, &"creep_melee", team, "MID", at)


func _cast(w: World, e: Entity, slot: int, ticks: int) -> bool:
	for i: int in range(ticks):
		w.step()
		for ev: GameEvent in w.events:
			if ev.type == &"ability_cast" and ev.source_id == e.id and int(ev.amount) == slot:
				return true
	return false


func _hurt(w: World, source: Entity, target: Entity) -> void:
	var r: DamageRequest = DamageRequest.new()
	r.source_id = source.id
	r.target_id = target.id
	r.raw = 10.0
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)


# ---------------------------------------------------------------- BOT-13 attacked_by_enemy_hero (D-392)

func test_BOT_13_attacked_by_enemy_hero_ignores_spell_and_creep_damage() -> void:
	var w: World = _world(false)
	var bot: Entity = _bot(w, &"phong_tien", _mid() + _dir() * 600.0)
	Abilities.set_rank(w, bot, Abilities.of(bot, S.Q), 1)
	var foe: Entity = _hero(w, 0, &"gorran", _mid() + _dir() * 1500.0)
	var creep: Entity = _creep(w, 0, _mid() + _dir() * 900.0)
	_hurt(w, foe, bot)  # như phép / độc của hero
	assert_false(_cast(w, bot, S.Q, 30), "sát thương không phải đòn đánh của hero: không né")
	_hurt(w, creep, bot)
	assert_false(_cast(w, bot, S.Q, 30), "lính: không né")


func test_BOT_13_attacked_by_enemy_hero_phong_tien_q_when_hero_hits() -> void:
	var w: World = _world(false)
	var bot: Entity = _bot(w, &"phong_tien", _mid())
	Abilities.set_rank(w, bot, Abilities.of(bot, S.Q), 1)
	var foe: Entity = _hero(w, 0, &"duy_anh", _mid() - _dir() * 120.0)
	w.submit(Command.attack(foe.id, bot.id))
	assert_true(_cast(w, bot, S.Q, 90), "bị hero địch đánh thường trúng: bật né đòn")


# ---------------------------------------------------------------- BOT-23 (D-393)

## Bot cận chiến đứng cạnh một lính địch; `own` lính phe bot đứng gần.
func _farm_scene(own: int, id: StringName = &"brakk", gap: float = 150.0) -> Array:
	var w: World = _world(true)
	var bot: Entity = _bot(w, id, _mid() + _dir() * gap)
	var foe_creep: Entity = _creep(w, 0, _mid())
	for i: int in range(own):
		_creep(w, 1, _mid() + _dir() * 90.0 + _dir().orthogonal() * (60.0 * (i - 0.5)))
	w.step()
	return [w, bot, foe_creep]


func test_BOT_23_melee_farm_skips_creep_when_no_cover() -> void:
	for own: int in [0, 1]:
		var s: Array = _farm_scene(own)
		assert_true(BotController.new().farm_target(s[0], s[1]) == null, "%d lính đỡ (< bot_creep_cover): không farm" % own)


func test_BOT_23_farm_with_enough_cover() -> void:
	var s: Array = _farm_scene(2)
	assert_true(BotController.new().farm_target(s[0], s[1]) == s[2], "đủ lính đỡ: farm như BOT-07")


func test_BOT_23_ranged_farm_from_range_is_not_exposed() -> void:
	var s: Array = _farm_scene(0, &"myra", 520.0)
	assert_true(BotController.new().farm_target(s[0], s[1]) == s[2], "đánh xa đứng ngoài tầm lính: farm được")


func test_BOT_23_no_trade_back_when_exposed() -> void:
	var w: World = _world(true)
	var bot: Entity = _bot(w, &"brakk", _mid() + _dir() * 100.0)
	var foe: Entity = _hero(w, 0, &"brakk", _mid() - _dir() * 100.0)
	_creep(w, 0, _mid() - _dir() * 60.0)
	_creep(w, 0, _mid() - _dir() * 60.0 + _dir().orthogonal() * 60.0)
	w.submit(Command.attack(foe.id, bot.id))
	var traded: bool = false
	for i: int in range(45):
		w.step()
		traded = traded or bot.bot.mode == Mode.TRADE
	assert_false(traded, "đánh trả phải đứng giữa lính địch không có lính đỡ: không TRADE")


func test_BOT_23_kill_ignores_creep_exposure() -> void:
	var w: World = _world(true)
	var bot: Entity = _bot(w, &"brakk", _mid() + _dir() * 150.0)
	var foe: Entity = _hero(w, 0, &"myra", _mid() - _dir() * 100.0)
	foe.health = foe.stats.get_stat(StatId.Id.MAX_HP) * 0.1
	_creep(w, 0, _mid() - _dir() * 60.0)
	var hunted: bool = false
	for i: int in range(15):
		w.step()
		hunted = hunted or bot.bot.mode == Mode.KILL
	assert_true(hunted, "KILL không xét BOT-23")
