extends TestCase
## D-159: mỗi khung MatchView3D đọc sự kiện của tick mới (hoạt ảnh chiêu, lóe khi trúng, rung camera).
## Lỗi tái hiện (D-177): một lần sửa làm lời gọi _dispatch_events() dính vào sau chú thích → không chạy.

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")


func test_D_159_update_dispatches_events_of_new_tick() -> void:
	var w: World = World.new(1, Fixture.make())
	w.step()
	var v: MatchView3D = MatchView3D.new()
	var units: UnitsView = UnitsView.new()
	units.world = w
	v.world = w
	v.units = units
	v.camera = Camera3D.new()
	v.add_child(v.camera)
	v.scenery = Scenery3D.new()
	v.add_child(v.scenery)
	v._layer_cam = Camera2D.new()
	v.add_child(v._layer_cam)
	v._ground = MeshInstance3D.new()
	v.add_child(v._ground)
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	root.add_child(v)
	v.update(Vector2.ZERO)
	assert_eq(v._event_tick, w.tick, "update đã đọc sự kiện của tick hiện tại")
	root.remove_child(v)
	v.free()
	units.free()
