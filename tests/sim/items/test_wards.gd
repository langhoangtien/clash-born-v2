extends TestCase
## M6.8a: ward — mắt vàng / mắt xanh (WRD-01..06), kho đội (SHOP-08), D-92.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const R := Command.Reject
const OBS: StringName = &"observer_ward"
const SEN: StringName = &"sentry_ward"

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(5, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.add_vision(w)
	MatchSetup.add_shop(w, _lib)
	return w


func _center() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-900, 900)


func _dir() -> Vector2:
	return Vector2(1, -1).normalized()


func _hero(w: World, team: int, at: Vector2, sight: float = -1.0) -> Entity:
	var h: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], team, w.navigation(32.0).nearest_clear(at))
	h.gold = 5000
	if sight >= 0.0:
		h.stats.set_base(StatId.Id.VISION_RANGE, sight)
		h.stats.recompute()
	return h


## Cắm ward loại `id` của `h` tại `at` (mua nếu chưa có); trả về ward mới.
func _place(w: World, h: Entity, id: StringName, at: Vector2) -> Entity:
	var slot: int = -1
	for it: ItemInstance in Items.slots(h):
		if it != null and it.def.id == id:
			slot = it.index
	if slot < 0:
		slot = Items.give(w, h, _lib.items[id])
	var before: Array[int] = _ward_ids(w)
	w.submit(Command.cast(h.id, Items.SLOT_BASE + slot, -1, at))
	_steps(w, 3)
	for e: Entity in w.entities:
		if e.kind == Entity.Kind.WARD and not before.has(e.id):
			return e
	return null


func _ward_ids(w: World) -> Array[int]:
	var out: Array[int] = []
	for e: Entity in w.entities:
		if e.kind == Entity.Kind.WARD:
			out.append(e.id)
	return out


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func _buy(w: World, h: Entity, id: StringName) -> R:
	w.submit(Command.buy(h.id, id))
	w.step()
	return w.rejected_commands[0].reject_reason if not w.rejected_commands.is_empty() else R.NONE


func test_WRD_01_place_ward_uses_charge_and_stacks_in_one_slot() -> void:
	var w: World = _world()
	var h: Entity = _hero(w, 0, _center())
	assert_eq(_buy(w, h, OBS), R.NONE)
	assert_eq(_buy(w, h, OBS), R.NONE)
	assert_eq(h.items[0].charges, 2, "mua thêm thì gộp vào cùng ô")
	assert_true(h.items[1] == null)
	var ward: Entity = _place(w, h, OBS, h.position + _dir() * 300.0)
	assert_true(ward != null, "cắm được")
	assert_eq(ward.team, 0)
	assert_true(ward.position.distance_to(h.position + _dir() * 300.0) < 40.0, "đúng chỗ")
	assert_eq(h.items[0].charges, 1, "tốn 1 lần cắm")
	var far: Entity = _place(w, h, OBS, h.position + _dir() * 2000.0)
	assert_true(far.position.distance_to(h.position) <= 500.0 + 1.0, "xa quá thì cắm ở mép tầm 500")
	assert_true(h.items[0] == null, "hết lần cắm thì món mất")


func test_WRD_02_ward_invisible_no_collision_expires_without_reward() -> void:
	var w: World = _world()
	var h: Entity = _hero(w, 0, _center())
	var foe: Entity = _hero(w, 1, _center() + _dir() * 300.0)
	var obs: Entity = _place(w, h, OBS, h.position + _dir() * 150.0)
	var sen: Entity = _place(w, h, SEN, h.position - _dir() * 150.0)
	assert_true(Rules.has_state(obs, UnitState.Id.INVISIBLE), "luôn tàng hình")
	assert_true(Rules.is_visible(0, obs), "phe mình luôn thấy")
	assert_false(Rules.is_visible(1, obs), "địch không thấy")
	assert_false(Rules.is_attackable(foe, obs))
	h.position = obs.position
	_steps(w, 5)
	assert_true(h.position.distance_to(obs.position) < 1.0, "không chắn / không đẩy đơn vị")
	var gold: int = foe.gold
	var gold_tick: int = w.tick
	while w.tick < 240 * 30 - 2:
		w.step()
	assert_true(obs.alive, "mắt vàng còn tới gần phút 4")
	_steps(w, 10)
	assert_false(w.entities.has(obs), "mắt vàng hết 4 phút thì mất")
	assert_true(w.entities.has(sen), "mắt xanh 5 phút")
	while w.tick < 300 * 30 + 10:
		w.step()
	assert_false(w.entities.has(sen), "mắt xanh hết 5 phút thì mất")
	assert_eq(foe.gold - gold, _passive(w, gold_tick, w.tick), "hết giờ thì không ai được thưởng")


func test_WRD_03_observer_vision_and_bush() -> void:
	var w: World = _world()
	var me: Entity = _hero(w, 0, _center(), 0.0)
	var obs: Entity = _place(w, me, OBS, me.position + _dir() * 100.0)
	me.position = _map.fountain_point(0)
	var near: Entity = _hero(w, 1, obs.position + _dir() * 1300.0)
	var far: Entity = _hero(w, 1, obs.position - _dir() * 1500.0)
	_steps(w, 2)
	assert_true(Rules.is_visible(0, near), "mắt vàng nhìn 1400")
	assert_false(Rules.is_visible(0, far))
	var bush: Vector2 = _map.bushes.polygons[0][0].lerp(_map.bushes.polygons[0][8], 0.5)
	var hider: Entity = _hero(w, 1, bush)
	hider.position = bush
	var watcher: Entity = _hero(w, 0, bush + _dir() * 300.0)
	var inside: Entity = _place(w, watcher, OBS, bush + Vector2(20, 0))
	watcher.position = _map.fountain_point(0)
	_steps(w, 2)
	assert_true(_map.bushes.at(inside.position) >= 0)
	assert_true(Rules.is_visible(0, hider), "mắt vàng trong bụi soi cả bụi")


func test_WRD_03_sentry_true_sight_needs_vision() -> void:
	var w: World = _world()
	var me: Entity = _hero(w, 0, _center())
	var sneak: Entity = _hero(w, 1, _center() + _dir() * 500.0)
	Effects.apply(w, sneak, _lib.effects[&"shadow_veil"], sneak, {&"fade_in": 0.0, &"move_bonus": 0.0}, "200")
	_steps(w, 2)
	assert_false(Rules.is_visible(0, sneak))
	var sen: Entity = _place(w, me, SEN, me.position + _dir() * 200.0)
	assert_true(Rules.is_visible(0, sneak), "mắt xanh: thấy tàng hình trong 900 khi có tầm nhìn")
	assert_true(Rules.is_attackable(me, sneak))
	var enemy_obs: Entity = _place(w, sneak, OBS, sneak.position + _dir() * 100.0)
	_steps(w, 2)
	assert_true(Rules.is_visible(0, enemy_obs), "thấy cả ward địch")
	me.position = _map.fountain_point(0)
	_steps(w, 2)
	assert_false(Rules.is_visible(0, sneak), "mắt xanh không cho tầm nhìn: không ai nhìn thì không thấy")
	assert_true(sen.alive)


func test_WRD_04_05_hero_destroys_in_two_hits_and_gets_bounty() -> void:
	var w: World = _world()
	var me: Entity = _hero(w, 0, _center())
	var foe: Entity = _hero(w, 1, _center() + _dir() * 250.0)
	var obs: Entity = _place(w, me, OBS, me.position + _dir() * 150.0)
	me.position = _map.fountain_point(0)
	var sen: Entity = _place(w, foe, SEN, foe.position + _dir() * 50.0)
	assert_true(Rules.is_attackable(foe, obs), "bị mắt xanh soi thì đánh được")
	var spell: AbilityDef = AbilityDef.new()
	assert_false(Abilities.accepts(foe, spell, obs), "chiêu không nhắm được ward")
	var r: DamageRequest = DamageRequest.new()
	r.source_id = foe.id
	r.target_id = obs.id
	r.raw = 9999.0
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)
	w.step()
	assert_true(obs.alive, "sát thương không phải đòn đánh thì không phá được")
	var gold: int = foe.gold
	w.submit(Command.attack(foe.id, obs.id))
	var hits: int = 0
	for i: int in range(150):
		w.step()
		hits += w.events.filter(func(ev: GameEvent) -> bool: return ev.type == &"attack_landed" and ev.target_id == obs.id).size()
		if not obs.alive:
			break
	assert_eq(hits, 2, "hero: 2 đòn")
	assert_false(obs.alive)
	assert_true(foe.gold - gold >= 150 and foe.gold - gold < 160, "phá mắt vàng: +150 vàng")
	assert_eq(foe.last_hits, 0, "không tính last hit")
	assert_true(sen.alive)


func test_WRD_04_06_tower_breaks_ward_last_in_six_hits() -> void:
	var w: World = _world()
	var me: Entity = _hero(w, 0, _center())
	var obs: Entity = _place(w, me, OBS, me.position + _dir() * 150.0)
	me.position = _map.fountain_point(0)
	var tower: Entity = UnitFactory.unit(w, _lib.units[&"tower_t1"], Entity.Kind.TOWER, 1, obs.position + _dir() * 300.0)
	var creep: Entity = UnitFactory.unit(w, _lib.units[&"creep_melee"], Entity.Kind.LANE_CREEP, 0, obs.position - _dir() * 100.0)
	creep.stats.set_base(StatId.Id.MOVEMENT_SPEED, 0.0)
	creep.stats.recompute()
	_steps(w, 3)
	assert_eq(tower.order.target_id, creep.id, "trụ đánh lính trước ward")
	creep.alive = false
	var hits: int = 0
	for i: int in range(12 * 30):
		w.step()
		hits += w.events.filter(func(ev: GameEvent) -> bool: return ev.type == &"attack_landed" and ev.target_id == obs.id).size()
		if not obs.alive:
			break
	assert_false(obs.alive, "trụ thấy ward trong tầm bắn (D-80) và phá")
	assert_eq(hits, 6, "trụ / lính: 6 đòn")


func test_WRD_06_attack_buttons_priority() -> void:
	var w: World = _world()
	var me: Entity = _hero(w, 0, _center())
	var foe: Entity = _hero(w, 1, _center() + _dir() * 200.0)
	var obs: Entity = _place(w, foe, OBS, foe.position + _dir() * 60.0)
	foe.position = _map.fountain_point(1)
	_place(w, me, SEN, me.position + _dir() * 100.0)
	var creep: Entity = UnitFactory.unit(w, _lib.units[&"creep_melee"], Entity.Kind.LANE_CREEP, 1, me.position + _dir() * 120.0)
	_steps(w, 2)
	assert_true(Rules.is_attackable(me, obs))
	assert_eq(Rules.pick_attack_target(w, me, Rules.AttackMode.CREEP), obs.id, "nút Lính: ward trước lính")
	assert_eq(Rules.pick_attack_target(w, me, Rules.AttackMode.ALL), creep.id, "nút Đánh: lính trước ward")


func test_SHOP_08_team_stock_and_restock() -> void:
	var w: World = _world()
	var a: Entity = _hero(w, 0, _center())
	var b: Entity = _hero(w, 1, _center() + _dir() * 3000.0)
	assert_eq(_buy(w, a, OBS), R.NONE)
	assert_eq(_buy(w, a, OBS), R.NONE)
	assert_eq(_buy(w, a, OBS), R.OUT_OF_STOCK, "kho đội 0 hết (có sẵn 2)")
	assert_eq(_buy(w, b, OBS), R.NONE, "kho mỗi đội riêng")
	assert_eq(Shop.stock(w, 0, w.item_catalog[OBS]), 0)
	while w.tick < 135 * 30 + 2:
		w.step()
	assert_eq(Shop.stock(w, 0, w.item_catalog[OBS]), 1, "135 s thêm 1")
	assert_eq(_buy(w, a, OBS), R.NONE)
	while w.tick < 135 * 30 * 6:
		w.step()
	assert_eq(Shop.stock(w, 1, w.item_catalog[OBS]), 4, "tối đa 4")
	assert_eq(Shop.stock(w, 0, w.item_catalog[&"reveal_dust"]), -1, "món không giới hạn")
	var h: PackedByteArray = w.state_hash()
	_buy(w, b, OBS)
	assert_true(w.state_hash() != h, "D-30")


## Vàng thụ động nhận được trong (from, to].
func _passive(w: World, from: int, to: int) -> int:
	var every: int = SimClock.seconds_to_ticks(w.balance.passive_gold_interval)
	return (to / every - from / every) * w.balance.passive_gold


func test_D_92_tap_ward_button_places_under_feet() -> void:
	var w: World = _world()
	var h: Entity = _hero(w, 0, _center())
	var slot: int = Items.give(w, h, _lib.items[OBS])
	var c: Command = QuickCast.command(w, h, Items.SLOT_BASE + slot)
	assert_eq(c.point, h.position, "chạm nút mắt: cắm dưới chân")
	assert_eq(QuickCast.ward_of(Abilities.of(h, Items.SLOT_BASE + slot)), _lib.units[&"ward_observer"])
	assert_eq(_buy(w, h, OBS), R.NONE)
	_buy(w, h, OBS)
	assert_eq(ShopPanel.status_text(w, _lib.items[OBS], R.OUT_OF_STOCK, 0), "Hết hàng, còn 135 s")
