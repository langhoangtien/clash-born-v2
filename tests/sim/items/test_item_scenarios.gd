extends TestCase
## M6.6: mỗi món đồ một kịch bản (CONTENT.md "Trang bị có kỹ năng"). Gậy Hồn Ma và Bột Lộ Diện
## đã có ở test_items.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const R := Command.Reject

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


func _center() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-900, 900)


func _hero(w: World, team: int = 0, offset: Vector2 = Vector2.ZERO, id: StringName = &"brakk") -> Entity:
	return UnitFactory.hero(w, _lib.heroes[id], team, w.navigation(32.0).nearest_clear(_center() + offset))


## [world, hero của mình có món đồ, hero địch cách 300].
func _pair(item: StringName) -> Array:
	var w: World = _world()
	var me: Entity = _hero(w)
	var foe: Entity = _hero(w, 1, Vector2(300, 0))
	Items.give(w, me, _lib.items[item])
	w.step()
	return [w, me, foe]


func _use(w: World, me: Entity, target: int = -1) -> R:
	w.submit(Command.cast(me.id, Items.SLOT_BASE, target))
	w.step()
	var r: R = w.rejected_commands[0].reject_reason if not w.rejected_commands.is_empty() else R.NONE
	_steps(w, 2)
	return r


func _has(e: Entity, id: StringName) -> bool:
	return e.effects.any(func(i: EffectInstance) -> bool: return i.def.id == id)


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func test_ITEM_cleansing_charm_basic_dispel_self() -> void:
	var p: Array = _pair(&"cleansing_charm")
	var w: World = p[0]
	Effects.apply(w, p[1], _lib.effects[&"silence"], p[2], {}, "5")
	assert_eq(_use(w, p[1]), R.NONE, "câm lặng không chặn đồ")
	assert_false(_has(p[1], &"silence"), "thanh tẩy cơ bản gỡ câm lặng")
	assert_true(Abilities.of(p[1], Items.SLOT_BASE).ready_tick > w.tick, "vào hồi chiêu 18 s")


func test_ITEM_cyclone_staff_lifts_enemy_or_self_not_magic_immune() -> void:
	var p: Array = _pair(&"cyclone_staff")
	var w: World = p[0]
	assert_eq(_use(w, p[1], p[2].id), R.NONE)
	for s: UnitState.Id in [UnitState.Id.STUNNED, UnitState.Id.INVULNERABLE, UnitState.Id.UNTARGETABLE]:
		assert_true(Rules.has_state(p[2], s), "địch bị nhấc lên: %s" % UnitState.Id.keys()[s])
	_steps(w, 80)
	assert_false(Rules.has_state(p[2], UnitState.Id.STUNNED), "hết 2.5 s")
	var q: Array = _pair(&"cyclone_staff")
	var g: World = q[0]
	assert_eq(_use(g, q[1], q[1].id), R.NONE, "dùng lên bản thân để né")
	assert_true(Rules.has_state(q[1], UnitState.Id.INVULNERABLE))
	var m: Array = _pair(&"cyclone_staff")
	var h: World = m[0]
	Effects.apply(h, m[2], _lib.effects[&"magic_immune"], m[2], {}, "5")
	h.step()
	assert_eq(_use(h, m[1], m[2].id), R.BAD_TARGET, "địch kháng phép thì không dùng được")


func test_ITEM_hex_scythe_hexes_for_3_5s() -> void:
	var p: Array = _pair(&"hex_scythe")
	var w: World = p[0]
	assert_eq(_use(w, p[1], p[2].id), R.NONE)
	assert_true(Rules.has_state(p[2], UnitState.Id.HEXED))
	assert_false(Rules.can_attack(p[2]), "biến hình thì không đánh được")
	_steps(w, 100)
	assert_true(Rules.has_state(p[2], UnitState.Id.HEXED), "còn ở 3.4 s")
	_steps(w, 6)
	assert_false(Rules.has_state(p[2], UnitState.Id.HEXED), "hết 3.5 s")


func test_ITEM_black_king_bar_dispels_then_magic_immune() -> void:
	var p: Array = _pair(&"black_king_bar")  # D-140: chủ động cũ của Giáp Bất Khuất
	var w: World = p[0]
	Effects.apply(w, p[1], _lib.effects[&"silence"], p[2], {}, "5")
	assert_eq(_use(w, p[1]), R.NONE)
	assert_false(_has(p[1], &"silence"), "thanh tẩy cơ bản trước")
	assert_true(Rules.has_state(p[1], UnitState.Id.MAGIC_IMMUNE), "rồi kháng phép 6 s")
	_steps(w, 6 * 30)
	assert_false(Rules.has_state(p[1], UnitState.Id.MAGIC_IMMUNE))


func test_ITEM_shadow_blade_invisible_after_fade_with_ambush() -> void:
	var p: Array = _pair(&"shadow_blade")
	var w: World = p[0]
	assert_eq(_use(w, p[1]), R.NONE)
	assert_true(_has(p[1], &"ambush_ready"), "đòn phục kích sẵn sàng")
	assert_false(Rules.has_state(p[1], UnitState.Id.INVISIBLE), "đang hiện dần 0.6 s")
	_steps(w, 20)
	assert_true(Rules.has_state(p[1], UnitState.Id.INVISIBLE))
	assert_false(Rules.is_visible(1, p[1]), "địch không thấy")


func test_ITEM_frost_orb_attack_slows_target() -> void:
	var p: Array = _pair(&"frost_orb")
	var w: World = p[0]
	p[2].position = p[1].position + Vector2(120, 0)
	var speed: float = p[2].stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	w.submit(Command.attack(p[1].id, p[2].id))
	for i: int in range(60):
		w.step()
		if _has(p[2], &"frost_orb_slow"):
			break
	assert_true(_has(p[2], &"frost_orb_slow"), "đòn đánh làm chậm")
	w.step()
	assert_near(p[2].stats.get_stat(StatId.Id.MOVEMENT_SPEED), speed * 0.8, 1.0, "chậm 20% tốc chạy")


func test_ITEM_stun_hammer_bashes_sometimes() -> void:
	var p: Array = _pair(&"stun_hammer")
	var w: World = p[0]
	p[2].position = p[1].position + Vector2(120, 0)
	p[2].stats.set_base(StatId.Id.MAX_HP, 100000)
	p[2].stats.recompute()
	p[2].health = 100000
	w.submit(Command.attack(p[1].id, p[2].id))
	var stunned: bool = false
	for i: int in range(60 * 30):
		w.step()
		if Rules.has_state(p[2], UnitState.Id.STUNNED):
			stunned = true
			break
	assert_true(stunned, "cận chiến 20%: trong 60 s có ít nhất một lần choáng")

