extends TestCase
## D-159: mỗi khung MatchView3D đọc sự kiện của tick mới (hoạt ảnh chiêu, lóe khi trúng, rung camera).
## Lỗi tái hiện (D-177): một lần sửa làm lời gọi _dispatch_events() dính vào sau chú thích → không chạy.
## D-180: không còn lớp 2D (SubViewport) — hình trên đất vẽ vào GroundCanvas, sương tính trong shader đất.

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")


func _view(w: World) -> MatchView3D:
	var v: MatchView3D = MatchView3D.new()
	var units: UnitsView = UnitsView.new()
	units.world = w
	v.add_child(units)
	v.world = w
	v.units = units
	v.camera = Camera3D.new()
	v.add_child(v.camera)
	v.scenery = Scenery3D.new()
	v.add_child(v.scenery)
	v._ground = MeshInstance3D.new()
	v.add_child(v._ground)
	v._ground_mat = ShaderMaterial.new()
	v._ground_mat.shader = preload("res://view/three/ground.gdshader")
	v.overlay = GroundCanvas.new()
	v.add_child(v.overlay)
	return v


func test_D_159_update_dispatches_events_of_new_tick() -> void:
	var w: World = World.new(1, Fixture.make())
	w.step()
	var v: MatchView3D = _view(w)
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	root.add_child(v)
	v.update(Vector2.ZERO)
	assert_eq(v._event_tick, w.tick, "update đã đọc sự kiện của tick hiện tại")
	root.remove_child(v)
	v.free()


func test_D_180_update_paints_ground_shapes_and_fog_eyes() -> void:
	var w: World = World.new(1, Fixture.make())
	var e: Entity = Entity.new()
	e.kind = Entity.Kind.HERO
	e.radius = 40.0
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.VISION_RANGE, 1200.0)
	e.position = Vector2(500, 500)
	w.add_entity(e)
	w.step()
	var v: MatchView3D = _view(w)
	v.fog_team = 0
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	root.add_child(v)
	v.update(Vector2(500, 500))
	assert_true(v.overlay.shape_count() > 0, "vòng đội của hero vẽ trên đất")
	assert_eq(v._ground_mat.get_shader_parameter("eye_count"), 1, "một mắt sương phe mình")
	var eyes: Array = v._ground_mat.get_shader_parameter("eyes")
	assert_near((eyes[0] as Vector4).z, 12.0, 0.001, "tầm nhìn đổi sang mét")
	root.remove_child(v)
	v.free()


func test_D_180_no_subviewport_in_match_scene() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var scene: Node = (load("res://app/match_scene.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	for vp: Node in scene.find_children("*", "SubViewport", true, false):
		assert_ne((vp as SubViewport).render_target_update_mode, SubViewport.UPDATE_ALWAYS, "không còn lớp vẽ lại vào ảnh phụ mỗi khung")
	assert_false((scene.get_node("MapView") as MapView).visible, "MapView chỉ giữ dữ liệu map trong trận")
	assert_true(scene.view_3d.marks.shape_count() > 0, "dấu cố định (bụi, shop, trại) dựng sẵn")
	scene.free()
