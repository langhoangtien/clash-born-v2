extends TestCase
## D-219: đạn đánh thường vẽ 3D trên không, hình theo đơn vị bắn (units_3d.json `projectile`); `arc` nâng độ cao
## giữa đường (chỉ là hình — sim vẫn bay thẳng theo mục tiêu, CMB-06). D-224: xe pháo bắn mảnh tinh thể.

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


func test_D_219_shape_per_source_and_arc() -> void:
	var heights: Dictionary = {}
	for pair: Array in [[&"creep_siege", "bolt", Entity.Kind.LANE_CREEP], [&"creep_ranged", "orb", Entity.Kind.LANE_CREEP],
			[&"tower", "rock", Entity.Kind.TOWER]]:
		var r: Array = _setup(pair[0], pair[2])
		(r[0] as World).find_entity((r[1] as Projectile).source_id).tier = 1
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
	assert_true(heights[&"tower"] > heights[&"creep_ranged"] + 0.3, "giữa đường đạn có arc (đá của trụ) bay cao hơn đạn thẳng")


## D-221: trụ là trụ đá — bắn viên đá như xe công thành (trước D-219 là mảnh tinh thể).
func test_D_221_tower_shoots_rock() -> void:
	var r: Array = _setup(&"tower", Entity.Kind.TOWER)
	(r[0] as World).find_entity((r[1] as Projectile).source_id).tier = 1
	var pj: Projectiles3D = Projectiles3D.new()
	pj.sync(r[0])
	assert_eq(pj.shape_of(r[1]), "rock", "trụ bắn viên đá")
	pj.free()


## D-294: đạn bay xong giữ lại (ẩn) để dùng lại — tạo mô hình + vật liệu mỗi viên làm giật 10–30 ms trên máy tính
## bảng (log L-0006, "đạn + sự kiện"); viên sau cùng loại, cùng phe lấy lại đúng nút đó.
func test_D_294_projectile_nodes_reused() -> void:
	var r: Array = _setup(&"tower", Entity.Kind.TOWER)
	var w: World = r[0]
	w.find_entity((r[1] as Projectile).source_id).tier = 1
	var pj: Projectiles3D = Projectiles3D.new()
	pj.sync(w)
	var first: Node3D = pj.node_of(r[1])
	w.projectiles.clear()
	pj.sync(w)
	assert_false(first.visible, "bay xong: ẩn, chưa xóa")
	assert_eq(pj.count(), 0)
	var again: Projectile = Projectile.new()
	again.source_id = (r[1] as Projectile).source_id
	again.target_id = (r[1] as Projectile).target_id
	w.projectiles.append(again)
	pj.sync(w)
	assert_true(pj.node_of(again) == first, "viên sau cùng loại dùng lại nút cũ")
	assert_true(first.visible)
	assert_eq(pj.get_child_count(), 1, "không tạo nút mới")
	pj.free()
