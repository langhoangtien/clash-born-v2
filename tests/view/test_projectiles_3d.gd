extends TestCase
## D-219: đạn đánh thường vẽ 3D trên không, hình theo đơn vị bắn (units_3d.json `projectile`); xe công thành
## bay vòng cung (chỉ là hình — sim vẫn bay thẳng theo mục tiêu, CMB-06).

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")


func _setup(art: StringName, kind: Entity.Kind) -> Array:
	var w: World = World.new(1, Fixture.make())
	var src: Entity = Entity.new()
	src.kind = kind
	src.team = 0
	src.art_id = art
	src.stats = StatBlock.new(w.balance)
	w.add_entity(src)
	var dst: Entity = Entity.new()
	dst.team = 1
	dst.position = Vector2(600, 0)
	dst.stats = StatBlock.new(w.balance)
	w.add_entity(dst)
	var p: Projectile = Projectile.new()
	p.source_id = src.id
	p.target_id = dst.id
	p.position = Vector2.ZERO
	w.projectiles.append(p)
	return [w, p]


func test_D_219_shape_per_source_and_siege_arcs() -> void:
	var heights: Dictionary = {}
	for pair: Array in [[&"creep_siege", "rock"], [&"creep_ranged", "orb"]]:
		var r: Array = _setup(pair[0], Entity.Kind.LANE_CREEP)
		var pj: Projectiles3D = Projectiles3D.new()
		pj.sync(r[0])
		assert_eq(pj.shape_of(r[1]), pair[1], "%s: hình đạn" % pair[0])
		(r[1] as Projectile).position = Vector2(300, 0)
		pj.sync(r[0])
		heights[pair[0]] = pj.node_of(r[1]).position.y
		(r[0] as World).projectiles.clear()
		pj.sync(r[0])
		assert_eq(pj.count(), 0, "đạn trúng / biến mất thì gỡ hình")
		pj.free()
	assert_true(heights[&"creep_siege"] > heights[&"creep_ranged"] + 1.0, "giữa đường đạn xe công thành bay cao (vòng cung)")


func test_D_219_tower_bolt() -> void:
	var r: Array = _setup(&"tower", Entity.Kind.TOWER)
	(r[0] as World).find_entity((r[1] as Projectile).source_id).tier = 1
	var pj: Projectiles3D = Projectiles3D.new()
	pj.sync(r[0])
	assert_eq(pj.shape_of(r[1]), "bolt", "trụ bắn mảnh tinh thể")
	pj.free()
