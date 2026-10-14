extends TestCase
## M5.1: VIEW theo tầm nhìn — không vẽ địch không thấy, sương mù, minimap giữ để xem chỗ khác.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"


func _world() -> World:
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = load(MAP_PATH) as MapLayout
	MatchSetup.add_vision(w)
	return w


func _unit(w: World, team: int, at: Vector2, sight: float, kind: Entity.Kind = Entity.Kind.HERO) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.position = at
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 100)
	e.stats.set_base(StatId.Id.VISION_RANGE, sight)
	return w.add_entity(e)


func test_units_view_hides_unseen_enemies_but_not_structures() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, Vector2(1000, 1000), 1200.0)
	var near: Entity = _unit(w, 1, Vector2(1500, 1000), 0.0)
	var far: Entity = _unit(w, 1, Vector2(5000, 1000), 0.0)
	var tower: Entity = _unit(w, 1, Vector2(6000, 1000), 0.0, Entity.Kind.TOWER)
	w.step()
	var view: UnitsView = UnitsView.new()
	view.world = w
	view.viewer_team = 0
	assert_true(view.seen(me) and view.seen(near))
	assert_false(view.seen(far), "địch ngoài tầm nhìn không vẽ")
	assert_true(view.seen(tower), "công trình luôn vẽ")
	view.viewer_team = -1
	assert_true(view.seen(far), "không đặt phe xem thì vẽ hết")
	view.free()


func test_fog_eyes_and_lit() -> void:
	var w: World = _world()
	_unit(w, 0, Vector2(1000, 1000), 1200.0)
	_unit(w, 0, Vector2(3000, 1000), 0.0)
	_unit(w, 1, Vector2(1200, 1000), 900.0)
	var eyes: Array[Vector4] = FogView.eyes(w, 0)
	assert_eq(eyes, [Vector4(1000, 1000, 1200, 0)], "chỉ đơn vị phe mình có tầm nhìn")
	assert_true(FogView.lit(w, 0, Vector2(2100, 1000)))
	assert_false(FogView.lit(w, 0, Vector2(2300, 1000)))


func test_minimap_hold_to_peek_then_release() -> void:
	var w: World = _world()
	var hero: Entity = _unit(w, 0, Vector2(1000, 1000), 1200.0)
	var m: Minimap = Minimap.new()
	m.setup(w, hero)
	assert_eq(m.to_map(Vector2(Minimap.SIDE, Minimap.SIDE) * 0.5), w.map.world_size() * 0.5)
	var press: InputEventScreenTouch = InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = Vector2(Minimap.SIDE * 0.75, Minimap.SIDE * 0.25)
	m._gui_input(press)
	assert_true(m.peeking)
	assert_eq(m.peek_point, w.map.world_size() * Vector2(0.75, 0.25))
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(Minimap.SIDE * 0.5, Minimap.SIDE * 0.5)
	m._gui_input(drag)
	assert_eq(m.peek_point, w.map.world_size() * 0.5, "kéo ngón thì camera theo")
	var other: InputEventScreenTouch = InputEventScreenTouch.new()
	other.index = 1
	other.pressed = false
	m._gui_input(other)
	assert_true(m.peeking, "ngón khác thả không ảnh hưởng")
	press.pressed = false
	m._gui_input(press)
	assert_false(m.peeking, "thả tay thì camera về hero")
	m.free()
