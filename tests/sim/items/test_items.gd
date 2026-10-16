extends TestCase
## M6.5a: ô đồ, chỉ số, bị động, chủ động, hồi chiêu chung, số lần dùng (ITM-01..04, 07, 08).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const EPS: float = 0.01

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.add_vision(w)
	return w


func _center() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-900, 900)


func _hero(w: World, team: int = 0, at: Vector2 = Vector2.INF) -> Entity:
	var p: Vector2 = at if at.is_finite() else _center()
	return UnitFactory.hero(w, _lib.heroes[&"brakk"], team, w.navigation(32.0).nearest_clear(p))


func _item(id: StringName) -> ItemDef:
	return _lib.items[id]


func _count(e: Entity, id: StringName) -> int:
	return e.effects.filter(func(i: EffectInstance) -> bool: return i.def.id == id).size()


func _reject(w: World, c: Command) -> Command.Reject:
	w.submit(c)
	w.step()
	return w.rejected_commands[0].reject_reason if not w.rejected_commands.is_empty() else Command.Reject.NONE


func test_ITM_01_six_slots_and_stats_as_modifiers() -> void:
	var w: World = _world()
	var h: Entity = _hero(w)
	var hp: float = h.stats.get_stat(StatId.Id.MAX_HP)
	assert_eq(Items.give(w, h, _item(&"frost_orb")), 0, "vào ô trống đầu tiên")
	h.stats.recompute()
	assert_true(h.stats.get_stat(StatId.Id.MAX_HP) > hp + 250.0, "+250 máu và +10 sức mạnh")
	for i: int in range(5):
		assert_eq(Items.give(w, h, _item(&"reveal_dust")), i + 1)
	assert_eq(Items.give(w, h, _item(&"reveal_dust")), -1, "6 ô đầy thì không nhận thêm")
	Items.remove(w, h, 0)
	h.stats.recompute()
	assert_near(h.stats.get_stat(StatId.Id.MAX_HP), hp, EPS, "bỏ đồ thì mất chỉ số")
	assert_eq(Items.give(w, h, _item(&"stun_hammer")), 0, "ô trống được dùng lại")


func test_ITM_04_07_duplicate_passive_applies_once_highest_slot_keeps_it() -> void:
	var w: World = _world()
	var h: Entity = _hero(w)
	Items.give(w, h, _item(&"stun_hammer"))
	assert_eq(_count(h, &"stun_hammer_passive"), 1, "bị động của đồ")
	Items.give(w, h, _item(&"stun_hammer"))
	assert_eq(_count(h, &"stun_hammer_passive"), 1, "hai món cùng loại: bị động chỉ một bản")
	var holder: EffectInstance = h.effects.filter(func(i: EffectInstance) -> bool: return i.def.id == &"stun_hammer_passive")[0]
	assert_eq(holder.item_slot, 2, "món ở ô cao nhất giữ bị động")
	Items.remove(w, h, 1)
	assert_eq(_count(h, &"stun_hammer_passive"), 1, "bỏ món giữ bị động thì món còn lại nhận")
	Items.remove(w, h, 0)
	assert_eq(_count(h, &"stun_hammer_passive"), 0)


func test_ITM_03_08_active_item_usable_when_silenced_not_when_stunned_or_hexed() -> void:
	var w: World = _world()
	var h: Entity = _hero(w)
	var foe: Entity = _hero(w, 1, _center() + Vector2(300, 0))
	Items.give(w, h, _item(&"ghost_scepter"))
	Effects.apply(w, h, _lib.effects[&"silence"], foe, {}, "5")
	assert_eq(_reject(w, Command.cast(h.id, Items.SLOT_BASE)), Command.Reject.NONE, "câm lặng không chặn đồ")
	w.step()
	assert_true(Rules.has_state(h, UnitState.Id.GHOST), "Gậy Hồn Ma: GHOST")
	var g: World = _world()
	var h2: Entity = _hero(g)
	var foe2: Entity = _hero(g, 1, _center() + Vector2(300, 0))
	Items.give(g, h2, _item(&"ghost_scepter"))
	Effects.apply(g, h2, _lib.effects[&"stun"], foe2, {}, "2")
	assert_eq(_reject(g, Command.cast(h2.id, Items.SLOT_BASE)), Command.Reject.CANNOT_CAST, "choáng thì không dùng được")
	_steps(g, 70)
	Effects.apply(g, h2, _lib.effects[&"hex"], foe2, {}, "2")
	assert_eq(_reject(g, Command.cast(h2.id, Items.SLOT_BASE)), Command.Reject.CANNOT_CAST, "biến hình thì không dùng được")


func test_ITM_04_same_items_share_cooldown() -> void:
	var w: World = _world()
	var h: Entity = _hero(w)
	Items.give(w, h, _item(&"ghost_scepter"))
	Items.give(w, h, _item(&"ghost_scepter"))
	w.submit(Command.cast(h.id, Items.SLOT_BASE))
	_steps(w, 2)
	assert_eq(_reject(w, Command.cast(h.id, Items.SLOT_BASE + 1)), Command.Reject.ON_COOLDOWN, "món cùng loại cũng vào hồi chiêu")
	var a: AbilityInstance = Abilities.of(h, Items.SLOT_BASE + 1)
	assert_eq(a.ready_tick - w.tick, 22 * 30 - 2, "hồi 22 s")


func test_ITM_07_charges_then_item_disappears() -> void:
	var w: World = _world()
	var h: Entity = _hero(w)
	var foe: Entity = _hero(w, 1, _center() + Vector2(600, 0))
	Effects.apply(w, foe, _lib.effects[&"shadow_veil"], foe, {&"fade_in": 0.0, &"move_bonus": 0.0}, "60")
	var slot: int = Items.give(w, h, _item(&"reveal_dust"))
	w.step()
	assert_false(Rules.is_visible(0, foe))
	w.submit(Command.cast(h.id, Items.SLOT_BASE + slot))
	_steps(w, 2)
	assert_true(Rules.is_visible(0, foe), "Bột Lộ Diện: lộ kẻ tàng hình trong 900")
	assert_eq(h.items[slot].charges, 1, "còn 1 lần dùng")
	Abilities.of(h, Items.SLOT_BASE + slot).ready_tick = 0
	w.submit(Command.cast(h.id, Items.SLOT_BASE + slot))
	_steps(w, 2)
	assert_true(h.items[slot] == null, "hết lần dùng thì món biến mất")


func test_D_30_items_in_hash() -> void:
	var w: World = _world()
	var h: Entity = _hero(w)
	var slot: int = Items.give(w, h, _item(&"reveal_dust"))
	var hash1: PackedByteArray = w.state_hash()
	h.items[slot].charges -= 1
	assert_true(w.state_hash() != hash1)


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()
