extends TestCase
## MOV-09 (D-388): điểm đến đứng được nhưng không có đường tới đúng điểm → đi tới chỗ đi được gần điểm đó nhất,
## không "xong" lệnh ngay mà đứng yên. Toạ độ thật từ trận brakk:noctis seed 2 phút 27:02 (D-380): một bên vách là
## chỗ đứng, bên kia là điểm sát mép vách nằm trong ô lưới bị chặn.

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")
const MAP_PATH: String = "res://data/maps/clashborn.tres"
const HERO_R: float = 32.0
const START: Vector2 = Vector2(8956.053, 2406.312)
const EDGE: Vector2 = Vector2(8675.446, 2493.861)

static var _map: MapLayout


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
	var w: World = World.new(3, Fixture.make())
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


func _unit(w: World, at: Vector2) -> Entity:
	var e: Entity = Entity.new()
	e.radius = HERO_R
	e.position = at
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 500)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.7)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300.0)
	return w.add_entity(e)


## Điều kiện của ca lỗi: điểm đứng được, nhưng không tìm được đường tới đúng điểm đó.
func _assert_unreachable_but_clear(w: World, to: Vector2) -> void:
	var nav: MapNavigation = w.navigation(HERO_R)
	assert_true(nav.point_is_clear(to), "điểm đến đứng được")
	assert_true(nav.path(START, to).is_empty(), "không có đường tới đúng điểm (ca MOV-09)")


func _walk(w: World, e: Entity, ticks: int) -> void:
	for t: int in range(ticks):
		w.step()
		if e.order.type == Order.Type.MOVE and e.order.finished:
			return


func test_MOV_09_player_click_at_wall_edge_walks_to_nearest_reachable_spot() -> void:
	var w: World = _world()
	_assert_unreachable_but_clear(w, EDGE)
	var h: Entity = _unit(w, START)
	w.submit(Command.move_to(h.id, EDGE))
	w.step()
	w.step()
	assert_false(h.order.finished, "lệnh không được xong ngay khi chưa đi")
	_walk(w, h, 600)
	assert_true(h.order.finished, "tới nơi thì xong lệnh (MOV-03)")
	assert_true(h.position.distance_to(START) > 200.0, "phải đi khỏi chỗ đứng, mới đi %.0f" % h.position.distance_to(START))
	var cell: float = w.navigation(HERO_R).cell_size
	assert_true(h.position.distance_to(EDGE) <= cell * 1.5, "dừng sát điểm bấm: còn cách %.0f" % h.position.distance_to(EDGE))
	assert_true(w.navigation(HERO_R).point_is_clear(h.position), "MOV-05: không đứng trong vật cản")


func test_MOV_09_bot_goes_to_nearest_clear_point_behind_wall() -> void:
	var w: World = _world()
	var nav: MapNavigation = w.navigation(HERO_R)
	var q: Vector2 = nav.nearest_clear(START + (_map.fountain_point(0) - START).normalized() * 300.0)  # cách bot chọn điểm trước D-380
	_assert_unreachable_but_clear(w, q)
	var h: Entity = _unit(w, START)
	h.bot = BotState.new()
	BotController.new()._go(w, h, q)
	for t: int in range(60):
		w.step()
	assert_true(h.position.distance_to(START) > 100.0, "BOT-11: 2 s phải rời chỗ, mới đi %.0f" % h.position.distance_to(START))
