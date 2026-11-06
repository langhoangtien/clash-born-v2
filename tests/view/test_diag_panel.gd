extends TestCase
## D-179: bảng chẩn đoán FPS — bấm ô đổi giá trị, báo `changed`, áp vào phần vẽ; không đụng World.


func _panel() -> DiagPanel:
	var p: DiagPanel = DiagPanel.new()
	p.open = true
	return p


func test_D_179_toggle_cell_flips_and_reports() -> void:
	var p: DiagPanel = _panel()
	var got: Array = []
	p.changed.connect(func(k: StringName, v: int) -> void: got.append([k, v]))
	p.press_at(p.cell_rect(DiagPanel.KEYS.find(&"scenery")).get_center())
	assert_eq(got, [[&"scenery", 0]], "cảnh vật bật → tắt")
	p.press_at(p.cell_rect(DiagPanel.KEYS.find(&"scenery")).get_center())
	assert_eq(p.value_of(&"scenery"), 1, "bấm lần nữa bật lại")
	p.free()


func test_D_179_scale_and_msaa_cycle() -> void:
	var p: DiagPanel = _panel()
	var seen: Array[int] = []
	for i: int in DiagPanel.SCALES.size():
		p.values[&"scale"] = i
		seen.append(p.value_of(&"scale"))
	assert_eq(seen, DiagPanel.SCALES, "độ phân giải quay vòng theo SCALES")
	p.values[&"msaa"] = DiagPanel.MSAAS.size() - 1
	p.values[&"msaa"] = (p.values[&"msaa"] + 1) % DiagPanel.MSAAS.size()
	assert_eq(p.value_of(&"msaa"), 0, "MSAA quay về tắt")
	p.free()


func test_D_179_set_part_hides_scenery_and_actors() -> void:
	var v: MatchView3D = MatchView3D.new()
	v.scenery = Scenery3D.new()
	v.add_child(v.scenery)
	v._ground = MeshInstance3D.new()
	v.add_child(v._ground)
	v._ground_mat = ShaderMaterial.new()
	v.set_part(&"scenery", false)
	assert_false(v.scenery.visible, "tắt cảnh vật")
	v.set_part(&"actors", false)
	assert_false(v._show_actors, "tắt nhân vật")
	v.set_part(&"ground", false)
	assert_true(v._ground.material_override is StandardMaterial3D, "nền phẳng thay nền ảnh")
	v.set_part(&"ground", true)
	assert_eq(v._ground.material_override, v._ground_mat, "bật lại nền ảnh")
	v.free()


func test_D_179_closed_panel_ignores_cells() -> void:
	var p: DiagPanel = DiagPanel.new()
	p.press_at(p.cell_rect(0).get_center())
	assert_eq(p.value_of(DiagPanel.KEYS[0]), 1, "bảng đóng: ô không phản ứng")
	p.free()


func test_D_266_fog_off_skips_eye_loop() -> void:
	var v: MatchView3D = MatchView3D.new()
	v.fog_team = 0
	v.set_part(&"fog", false)
	var eyes: Array[Vector4] = v.fog_eyes(Vector2.ZERO)
	assert_eq(eyes.size(), 1, "tắt sương: shader chỉ chạy 1 vòng (một mắt phủ hết), không duyệt mắt phe mình")
	assert_true(eyes[0].z > 1000.0)
	v.free()


func test_D_268_vfx_cell_hides_skill_effects_and_projectiles() -> void:
	assert_true(DiagPanel.KEYS.has(&"vfx"), "ô Hiệu ứng cho đo A/B")
	var v: MatchView3D = MatchView3D.new()
	v.add_child(v.skill_vfx)
	v.add_child(v.projectiles)
	v.set_part(&"vfx", false)
	assert_false(v.skill_vfx.visible)
	assert_false(v.projectiles.visible)
	v.set_part(&"vfx", true)
	assert_true(v.skill_vfx.visible and v.projectiles.visible)
	v.free()
