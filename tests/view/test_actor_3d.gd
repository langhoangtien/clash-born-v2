extends TestCase
## Nhân vật 3D (D-157, D-161): phe mình núp bụi / tàng hình (VIS-06, VIS-02) vẽ mờ bằng vật liệu trong suốt
## — trình vẽ Compatibility bỏ qua GeometryInstance3D.transparency nên phải đổi vật liệu.

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")


func _hero_actor() -> Array:
	var w: World = World.new(1, Fixture.make())
	var e: Entity = Entity.new()
	e.kind = Entity.Kind.HERO
	e.team = 0
	e.art_id = &"duy_anh"
	e.stats = StatBlock.new(w.balance)
	w.add_entity(e)
	return [w, e, Actor3D.make(e)]


func _all_transparent(a: Actor3D) -> bool:
	for n: Node in a.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh is QuadMesh:
			continue  # bóng mờ dưới chân
		for i: int in mi.mesh.get_surface_count():
			var m: BaseMaterial3D = mi.get_active_material(i) as BaseMaterial3D
			if m == null or m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				return false
	return true


func test_VIS_06_faded_actor_uses_transparent_materials() -> void:
	var r: Array = _hero_actor()
	var a: Actor3D = r[2]
	a.sync(r[0], r[1], Vector3.ZERO, false, -100, true)
	assert_true(_all_transparent(a), "mọi lưới (cả vũ khí) trong suốt khi mờ")
	a.sync(r[0], r[1], Vector3.ZERO, false, -100, false)
	assert_false(_all_transparent(a), "hết mờ thì về vật liệu đặc")
	a.free()


## Lỗi người chơi báo (D-208): quái vừa đánh xong đuổi theo thì trượt trên đất — pha thu tay vẫn phát hoạt ảnh
## đánh dù đang đi. CMB-06: thu tay bị di chuyển hủy, hoạt ảnh theo sim → đang đi thì chạy.
func test_CMB_06_recovery_while_moving_plays_run() -> void:
	var w: World = World.new(1, Fixture.make())
	var e: Entity = Entity.new()
	e.kind = Entity.Kind.NEUTRAL
	e.team = 2
	e.art_id = &"neutral_wolf"
	e.stats = StatBlock.new(w.balance)
	w.add_entity(e)
	var a: Actor3D = Actor3D.make(e)
	e.attack_phase = Entity.AttackPhase.RECOVERY
	a.sync(w, e, Vector3.ZERO, false, -100, false)
	assert_eq(a._playing, "attack", "thu tay đứng yên: hoạt ảnh đánh")
	a.sync(w, e, Vector3.ZERO, true, -100, false)
	assert_eq(a._playing, "run", "thu tay mà đang đi: chạy, không trượt")
	a.sync(w, e, Vector3.ZERO, false, -100, false)
	assert_eq(a._playing, "idle", "đã thôi đòn thì không quay lại hoạt ảnh đánh")
	a.free()
