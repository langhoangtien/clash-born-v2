extends TestCase
## D-104: về thành (RCL-01..02).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> Array:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	var h: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], 0, w.navigation(32.0).nearest_clear(_map.world_size() * 0.5))
	return [w, h]


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func _events(w: World, type: StringName) -> int:
	return w.events.filter(func(ev: GameEvent) -> bool: return ev.type == type).size()


func test_RCL_01_channel_then_teleport_home() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var h: Entity = s[1]
	var spot: Vector2 = h.position
	w.submit(Command.recall(h.id))
	w.step()
	assert_eq(_events(w, &"recall_started"), 1)
	_steps(w, 8 * 30 - 2)
	assert_eq(h.position, spot, "đứng yên trong lúc kênh")
	_steps(w, 2)
	assert_true(h.position.distance_to(_map.fountain_point(0)) < 100.0, "8 s thì về fountain")


func test_RCL_02_cancelled_by_new_order_damage_or_stun() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var h: Entity = s[1]
	w.submit(Command.recall(h.id))
	_steps(w, 30)
	w.submit(Command.move_to(h.id, h.position + Vector2(200, 0)))
	_steps(w, 9 * 30)
	assert_true(h.position.distance_to(_map.fountain_point(0)) > 2000.0, "đi là hủy")
	w.submit(Command.recall(h.id))
	_steps(w, 30)
	var r: DamageRequest = DamageRequest.new()
	r.source_id = -1
	r.target_id = h.id
	r.raw = 10.0
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)
	w.step()
	assert_eq(_events(w, &"recall_cancelled"), 1, "trúng sát thương là hủy")
	assert_eq(h.recall_until_tick, -1)
	w.submit(Command.recall(h.id))
	_steps(w, 30)
	Effects.apply(w, h, _lib.effects[&"stun"], null, {}, "1")
	_steps(w, 2)
	assert_eq(h.recall_until_tick, -1, "choáng là hủy")
	Effects.apply(w, h, _lib.effects[&"stun"], null, {}, "1")
	w.step()
	w.submit(Command.recall(h.id))
	w.step()
	assert_eq(w.rejected_commands.size(), 1, "đang choáng không về thành được")
	var hash1: PackedByteArray = w.state_hash()
	h.recall_until_tick = 5
	assert_true(w.state_hash() != hash1, "D-30")
