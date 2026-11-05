extends TestCase
## D-264: tối ưu SIM không đổi kết quả — tầm trụ loại nhanh (D-80), nhớ bụi theo vị trí (VIS-06), tra lưới đơn vị.

const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"


func _body(w: World, team: int, kind: Entity.Kind, at: Vector2, radius: float, attack_range: float) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.radius = radius
	e.position = at
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 1000)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, attack_range)
	return w.add_entity(e)


func test_D_80_tower_sees_exactly_to_edge_of_attack_range() -> void:
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	MatchSetup.add_vision(w)
	var c: Vector2 = Vector2(4000, 4000)
	_body(w, 0, Entity.Kind.TOWER, c, 100.0, 700.0)
	var dirs: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2(1, 1).normalized(), Vector2(-3, 4).normalized()]
	var edge: Array[Entity] = []
	var out: Array[Entity] = []
	for d: Vector2 in dirs:
		edge.append(_body(w, 1, Entity.Kind.HERO, c + d * 823.9, 24.0, 100.0))
		out.append(_body(w, 1, Entity.Kind.HERO, c + d * 824.6, 24.0, 100.0))
	w.step()
	for e: Entity in edge:
		assert_true(e.visible_mask & 1 != 0, "mép thân trong tầm bắn trụ: trụ thấy (D-80)")
	for e: Entity in out:
		assert_true(e.visible_mask & 1 == 0, "ngoài tầm bắn trụ nửa đơn vị: không thấy")


func _world_with_bush() -> World:
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = load("res://data/maps/clashborn.tres") as MapLayout
	MatchSetup.add_vision(w)
	return w


func test_VIS_06_bush_follows_unit_after_moving_and_death() -> void:
	var w: World = _world_with_bush()
	var poly: PackedVector2Array = w.map.bushes.polygons[0]
	var inside: Vector2 = Vector2.ZERO
	for p: Vector2 in poly:
		inside += p
	inside /= poly.size()
	assert_eq(w.map.bushes.at(inside), 0, "tâm bụi 0 nằm trong bụi 0")
	var e: Entity = Entity.new()
	e.team = 0
	e.radius = 24.0
	e.position = inside
	e.stats = StatBlock.new(w.balance)
	w.add_entity(e)
	w.step()
	assert_eq(e.bush_id, 0)
	e.position = Vector2(-5000, -5000)
	w.step()
	assert_eq(e.bush_id, -1, "ra khỏi bụi")
	e.position = inside
	w.step()
	assert_eq(e.bush_id, 0, "vào lại bụi")
	e.alive = false
	w.step()
	assert_eq(e.bush_id, -1, "chết: không ở bụi nào")
	e.alive = true
	w.step()
	assert_eq(e.bush_id, 0, "sống lại cùng chỗ: lại trong bụi")


func test_D_264_spatial_near_same_set_and_order_as_full_scan() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9
	var list: Array[Entity] = []
	for i: int in 150:
		var e: Entity = Entity.new()
		e.id = i
		e.radius = [20.0, 30.0, 150.0][i % 3]
		e.position = Vector2(rng.randf_range(-100, 9300), rng.randf_range(-100, 9300))
		e.alive = i % 11 != 0
		list.append(e)
	var grid: SpatialGrid = SpatialGrid.new()
	grid.rebuild(list, 1, 0)
	for k: int in 300:
		var at: Vector2 = Vector2(rng.randf_range(-300, 9500), rng.randf_range(-300, 9500))
		var r: float = rng.randf_range(10, 1200)
		var got: Array[Entity] = grid.near(at, r)
		var want: Array[Entity] = []
		for e: Entity in list:
			if e.alive and e.position.distance_squared_to(at) <= (r + 150.0) * (r + 150.0):
				want.append(e)
		assert_eq(got, want, "sắp theo id, đủ mọi đơn vị sống trong r + bán kính lớn nhất")
