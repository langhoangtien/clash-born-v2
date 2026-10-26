extends TestCase
## D-167: giày không cộng dồn tốc chạy (STAT-05), kháng hiệu ứng nhân dồn (ST-09), Rìu Chiến
## đánh lan (ABL-22), Đao Tán Ma đốt mana (CMB-10).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(7, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.add_vision(w)
	return w


func _hero(w: World, team: int, offset: Vector2, id: StringName = &"brakk") -> Entity:
	var at: Vector2 = _map.world_size() * 0.5 + Vector2(-900, 900) + offset
	var h: Entity = UnitFactory.hero(w, _lib.heroes[id], team, at)
	h.stats.set_base(StatId.Id.MAX_HP, 100000)
	h.stats.recompute()
	h.health = 100000
	return h


## Đánh tới khi `target` mất máu lần đầu; trả về số tick đã chạy.
func _first_hit(w: World, me: Entity, target: Entity) -> void:
	w.submit(Command.attack(me.id, target.id, true))
	for i: int in range(120):
		w.step()
		if target.health < 100000:
			return


func test_STAT_05_boots_movement_speed_does_not_stack() -> void:
	var w: World = _world()
	var me: Entity = _hero(w, 0, Vector2.ZERO)
	w.step()
	var base: float = me.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	Items.give(w, me, _lib.items[&"boots"])
	Items.give(w, me, _lib.items[&"boots_haste"])
	Items.give(w, me, _lib.items[&"boots_guard"])
	w.step()
	assert_near(me.stats.get_stat(StatId.Id.MOVEMENT_SPEED), base + 55.0, 0.01, "chỉ đôi giày ở ô sau cùng có tác dụng")


func test_ST_09_status_resistance_sources_multiply() -> void:
	var w: World = _world()
	var me: Entity = _hero(w, 0, Vector2.ZERO)
	Items.give(w, me, _lib.items[&"status_charm"])
	Items.give(w, me, _lib.items[&"steadfast_armor"])
	w.step()
	assert_near(me.stats.get_stat(StatId.Id.STATUS_RESISTANCE), 1.0 - 0.9 * 0.8, 0.0001, "10% và 20% → 28%")


func test_ABL_22_battle_axe_cleaves_others_in_front_only_for_melee() -> void:
	var w: World = _world()
	var me: Entity = _hero(w, 0, Vector2.ZERO)
	var foe: Entity = _hero(w, 1, Vector2(120, 0))
	var side: Entity = _hero(w, 1, Vector2(200, 80))
	var behind: Entity = _hero(w, 1, Vector2(-200, 0))
	Items.give(w, me, _lib.items[&"battle_axe"])
	w.step()
	_first_hit(w, me, foe)
	assert_true(foe.health < 100000, "đòn chính trúng")
	assert_true(side.health < 100000, "kẻ địch trong quạt phía trước bị đánh lan")
	assert_true(behind.health >= 100000.0, "phía sau không bị lan")
	assert_true(100000 - foe.health > 100000 - side.health, "lan 50% (trước giáp) nhỏ hơn đòn chính")


func test_ABL_22_battle_axe_no_cleave_when_ranged() -> void:
	var w: World = _world()
	var me: Entity = _hero(w, 0, Vector2.ZERO, &"myra")
	var foe: Entity = _hero(w, 1, Vector2(300, 0))
	var side: Entity = _hero(w, 1, Vector2(330, 60))
	Items.give(w, me, _lib.items[&"battle_axe"])
	w.step()
	_first_hit(w, me, foe)
	assert_true(foe.health < 100000, "đòn chính trúng")
	assert_true(side.health >= 100000.0, "đánh xa không đánh lan")


func test_CMB_10_diffusal_burns_mana_and_deals_burned_as_damage() -> void:
	var dealt: Array[float] = []
	for mana: float in [0.0, 100.0]:
		var w: World = _world()
		var me: Entity = _hero(w, 0, Vector2.ZERO)
		var foe: Entity = _hero(w, 1, Vector2(120, 0), &"noctis")
		Items.give(w, me, _lib.items[&"diffusal_blade"])
		w.step()
		foe.mana = mana
		_first_hit(w, me, foe)
		w.step()
		if mana > 0.0:
			assert_near(foe.mana, 60.0, 1.0, "cận chiến đốt 40 mana")
		dealt.append(100000.0 - foe.health)
	assert_true(dealt[1] - dealt[0] > 25.0, "thêm sát thương vật lý bằng mana đã đốt (40 trước giáp): %s" % [dealt])
