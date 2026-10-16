extends TestCase
## M6.7: chặn chết và tái sinh tại chỗ (DTH-01..03). Hero thử nghiệm kiểu Wraith King dựng
## bằng dữ liệu (chép Brakk, R = bị động Tái sinh), không vào game.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const EPS: float = 0.01
const PURE := DamageFormulas.DamageType.PURE

static var _map: MapLayout
static var _lib: ContentLibrary
static var _king: HeroDef


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
		_king = _make_king()
	var w: World = World.new(3, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


## Tái sinh kiểu Wraith King: R bị động, hồi 120 s, tốn 160 mana; on_learn áp hiệu ứng `prevent_death`.
static func _make_king() -> HeroDef:
	var effect: EffectDef = EffectDef.new()
	effect.id = &"test_reincarnation"
	effect.duration = "0"
	effect.tags = [&"passive"]
	effect.prevent_death = true
	var give: ApplyEffectAction = ApplyEffectAction.new()
	give.effect = effect
	give.target = ActionDef.Target.SELF
	var r: AbilityDef = AbilityDef.new()
	r.id = &"test_reincarnation_ability"
	r.slot = AbilityDef.Slot.R
	r.targeting = AbilityDef.Targeting.PASSIVE
	r.values = {&"cooldown": PackedFloat32Array([120, 100, 80]), &"mana": PackedFloat32Array([160, 160, 160])}
	r.on_learn = [give]
	var king: HeroDef = _lib.heroes[&"brakk"].duplicate()
	king.id = &"test_king"
	king.r = r
	return king


func _center() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-900, 900)


## [world, vua đã học Tái sinh, hero địch].
func _setup() -> Array:
	var w: World = _world()
	var king: Entity = UnitFactory.hero(w, _king, 0, w.navigation(32.0).nearest_clear(_center()), 6)
	var foe: Entity = UnitFactory.hero(w, _lib.heroes[&"myra"], 1, w.navigation(32.0).nearest_clear(_center() + Vector2(400, 0)), 6)
	Abilities.set_rank(w, king, Abilities.of(king, AbilityDef.Slot.R), 1)
	king.mana = 300.0
	w.step()
	return [w, king, foe]


func _hit(w: World, source: Entity, target: Entity, amount: float) -> void:
	var r: DamageRequest = DamageRequest.new()
	r.source_id = source.id
	r.target_id = target.id
	r.raw = amount
	r.damage_type = PURE
	w.damage_requests.append(r)


func _events(w: World, type: StringName) -> int:
	return w.events.filter(func(ev: GameEvent) -> bool: return ev.type == type).size()


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func test_DTH_01_prevents_when_ready_and_enough_mana() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var king: Entity = s[1]
	var foe: Entity = s[2]
	var spot: Vector2 = king.position
	_hit(w, foe, king, 100000.0)
	w.step()
	assert_true(king.alive, "không chết")
	assert_near(king.health, 1.0, EPS, "máu giữ ở 1")
	assert_eq(_events(w, &"lethal_damage"), 1)
	assert_eq(_events(w, &"unit_died"), 0, "chưa chết thật")
	assert_near(king.mana, 140.0, 0.5, "trừ 160 mana")
	var r: AbilityInstance = Abilities.of(king, AbilityDef.Slot.R)
	assert_eq(r.ready_tick - w.tick, 120 * 30, "vào hồi chiêu 120 s")
	assert_eq(king.position, spot, "nằm tại chỗ")


func test_DTH_01_dies_when_on_cooldown_or_low_mana() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var king: Entity = s[1]
	king.mana = 100.0
	_hit(w, s[2], king, 100000.0)
	w.step()
	assert_false(king.alive, "thiếu mana: chết thật")
	var t: Array = _setup()
	var g: World = t[0]
	var k2: Entity = t[1]
	_hit(g, t[2], k2, 100000.0)
	g.step()
	_steps(g, 4 * 30)
	assert_true(k2.alive and k2.reincarnate_tick < 0, "đã đứng dậy")
	_hit(g, t[2], k2, 100000.0)
	g.step()
	assert_false(k2.alive, "lần thứ hai trong 120 s: chết thật")


func test_DTH_02_lies_down_invulnerable_then_stands_up_full() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var king: Entity = s[1]
	var foe: Entity = s[2]
	Effects.apply(w, king, _lib.effects[&"silence"], foe, {}, "20")
	var buff: EffectDef = EffectDef.new()
	buff.id = &"test_buff"
	buff.tags = [&"buff"]
	Effects.apply(w, king, buff, king, {}, "20")
	_hit(w, foe, king, 100000.0)
	_hit(w, foe, king, 100000.0)
	w.step()
	assert_true(king.alive, "hai đòn chết cùng tick chỉ tính một lần")
	assert_eq(_events(w, &"lethal_damage"), 1)
	for st: UnitState.Id in [UnitState.Id.INVULNERABLE, UnitState.Id.UNTARGETABLE, UnitState.Id.STUNNED]:
		assert_true(Rules.has_state(king, st), "đang nằm: %s" % UnitState.Id.keys()[st])
	assert_false(Rules.is_targetable(foe, king), "không bị nhắm")
	assert_eq(king.order.type, Order.Type.IDLE, "lệnh bị hủy")
	_hit(w, foe, king, 100000.0)
	w.step()
	assert_eq(_events(w, &"damage_taken"), 0, "bất tử khi nằm")
	assert_true(king.alive)
	w.step()
	_steps(w, 3 * 30 - 4)
	assert_true(king.reincarnate_tick >= 0, "chưa hết 3 s")
	_steps(w, 3)
	assert_eq(king.reincarnate_tick, -1, "đứng dậy sau 3 s")
	assert_near(king.health, king.stats.get_stat(StatId.Id.MAX_HP), EPS, "đầy máu")
	assert_near(king.mana, king.stats.get_stat(StatId.Id.MAX_MANA), EPS, "đầy mana")
	assert_false(king.effects.any(func(i: EffectInstance) -> bool: return i.def.id == &"silence"), "mọi debuff bị gỡ")
	assert_true(king.effects.any(func(i: EffectInstance) -> bool: return i.def.id == &"test_buff"), "buff giữ nguyên")
	assert_false(Rules.has_state(king, UnitState.Id.STUNNED))
	assert_true(Rules.can_attack(king), "hành động lại được")


func test_DTH_03_counts_as_kill_without_respawn_or_gold_loss() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var king: Entity = s[1]
	var foe: Entity = s[2]
	king.gold = 1000
	foe.gold = 0
	var xp: float = foe.xp
	_hit(w, foe, king, 100000.0)
	w.step()
	assert_eq(_events(w, &"kill_credited"), 1)
	var b: BalanceSettings = w.balance
	assert_eq(foe.gold, b.hero_kill_gold_base + b.hero_kill_gold_per_level * king.stats.level(), "kẻ hạ nhận vàng")
	assert_true(foe.xp > xp, "kẻ hạ nhận XP")
	assert_eq(foe.kills, 1)
	assert_eq(king.deaths, 1)
	assert_eq(king.gold, 1000, "không mất vàng")
	assert_eq(king.respawn_tick, -1, "không có thời gian chờ hồi sinh")
	_steps(w, 4 * 30)
	assert_true(king.alive)


func test_DTH_02_reincarnated_event_and_hash() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var king: Entity = s[1]
	_hit(w, s[2], king, 100000.0)
	w.step()
	var h: PackedByteArray = w.state_hash()
	king.reincarnate_tick += 1
	assert_true(w.state_hash() != h, "D-30")
	king.reincarnate_tick -= 1
	var seen: int = 0
	for i: int in range(4 * 30):
		w.step()
		seen += _events(w, &"reincarnated")
	assert_eq(seen, 1, "phát reincarnated khi đứng dậy")


func test_DTH_01_effect_without_ability_is_used_once() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var foe: Entity = s[2]
	var aegis: EffectDef = EffectDef.new()
	aegis.id = &"test_aegis"
	aegis.duration = "0"
	aegis.tags = [&"buff"]
	aegis.prevent_death = true
	Effects.apply(w, foe, aegis, foe)
	_hit(w, s[1], foe, 100000.0)
	w.step()
	assert_true(foe.alive and foe.reincarnate_tick >= 0, "không gắn kỹ năng: chặn được (kiểu Aegis)")
	assert_false(foe.effects.any(func(i: EffectInstance) -> bool: return i.def.id == &"test_aegis"), "dùng xong thì mất")
	_steps(w, 4 * 30)
	_hit(w, s[1], foe, 100000.0)
	w.step()
	assert_false(foe.alive, "lần sau chết thật")
