extends TestCase
## D-276: canh lỗi "VIEW đọc trạng thái giữa hai nửa tick" (D-273 / D-275). Trận thật có cảnh 3D, chia tick, tướng
## do bot; chạy từng khung 60 fps: không đơn vị nào bị báo chạy → đứng → chạy trong ba khung liền, hoạt ảnh mô
## hình 3D không nháy giữa chạy và đứng.

const SCENE: String = "res://app/match_scene.tscn"
const FRAMES: int = 240


func test_D_276_no_run_idle_flicker_with_split_ticks() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	scene.set_process(false)
	assert_true(scene.runner.split_ticks, "trận thật chia tick")
	MatchSetup.add_bot(scene.world, scene.hero)
	var moving: Dictionary = {}  # id → [3 khung gần nhất]
	var anims: Dictionary = {}
	var flicker: Array[String] = []
	var mid_frames: int = 0
	var moved: int = 0
	for f: int in FRAMES:
		scene.tick_frame(1.0 / 60.0)
		mid_frames += 1 if scene.world.mid_tick else 0
		for e: Entity in scene.world.entities:
			var m: bool = scene.units_view.is_moving(e)
			moved += 1 if m else 0
			_push(moving, e.id, m)
			if _flickers(moving[e.id]):
				flicker.append("đơn vị %d khung %d: chạy/đứng nháy" % [e.id, f])
		for a: Variant in scene.view_3d._actors.values():
			var actor: Actor3D = a
			if actor._rig.is_empty():
				continue
			var kind: String = "run" if actor._playing == actor._rig["run"] else ("idle" if actor._playing == actor._rig["idle"] else "")
			if kind != "":
				_push(anims, actor.get_instance_id(), kind == "run")
				if _flickers(anims[actor.get_instance_id()]):
					flicker.append("hình 3D khung %d: hoạt ảnh chạy/đứng nháy" % f)
	assert_true(mid_frames > FRAMES / 4, "có khung nằm giữa hai nửa tick (đúng là đang chia)")
	assert_true(moved > 0, "có đơn vị di chuyển để kiểm")
	assert_eq(flicker.slice(0, 5), [], "không nháy")
	scene.free()


static func _push(d: Dictionary, key: int, v: bool) -> void:
	var list: Array = d.get(key, [])
	list.append(v)
	if list.size() > 3:
		list.pop_front()
	d[key] = list


## true → false → true (hoặc ngược lại) trong ba khung liền.
static func _flickers(list: Array) -> bool:
	return list.size() == 3 and list[0] == list[2] and list[0] != list[1]
