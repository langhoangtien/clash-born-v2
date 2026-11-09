extends TestCase
## D-158, D-178: cảnh 3D dựng từ dữ liệu map (decor.py) — mô hình có thật, cây chỉ trên bục rừng, mặt nạ nền
## phủ cả map; đổ nát xuất hiện chỗ trụ đã đổ.

const MAP_PATH: String = "res://data/maps/clashborn.tres"


func test_D_178_decor_models_exist() -> void:
	var seen: Dictionary = {}
	for it: Array in Terrain3D.items():
		seen[it[0]] = true
	assert_true(seen.size() >= 10, "đủ loại cảnh vật (%d)" % seen.size())
	for model: String in seen:
		assert_true(ResourceLoader.exists(ModelLibrary.MODELS + Terrain3D.MODEL_DIR + model + ".glb"), "có mô hình %s" % model)


func test_D_178_trees_only_on_plateaus() -> void:
	var layout: MapLayout = load(MAP_PATH) as MapLayout
	var trees: int = 0
	for it: Array in Terrain3D.items():
		if not String(it[0]).begins_with("pine") and not String(it[0]).begins_with("tree"):
			continue
		trees += 1
		var p: Vector2 = Vector2(float(it[1]), float(it[2]))
		var inside: bool = false
		for shape: MapShape in layout.forest_shapes:
			inside = inside or Geometry2D.is_point_in_polygon(p, shape.outer)
		assert_true(inside, "cây tại %s nằm trong bục rừng" % p)
	assert_true(trees > 100, "rừng có cây (%d)" % trees)


func test_D_178_ground_masks_cover_map() -> void:
	var rect: Rect2 = Terrain3D.mask_rect()
	var size: Vector2 = (load(MAP_PATH) as MapLayout).world_size()
	assert_true(rect.encloses(Rect2(Vector2.ZERO, size)), "mặt nạ phủ cả map")
	assert_eq(Terrain3D.mask_image().get_size(), Terrain3D.depth_image().get_size(), "D-180: ảnh độ sâu nước cùng lưới mặt nạ (bóng ở kênh A mặt nạ)")


func test_D_158_rubble_appears_where_tower_fell() -> void:
	var layout: MapLayout = load(MAP_PATH) as MapLayout
	var w: World = World.new(1, BalanceSettings.new())
	w.map = layout
	var s: Scenery3D = Scenery3D.new()
	s._layout = layout
	var before: int = s.get_child_count()
	w.destroyed_structures[StringName(layout.tower_ids[0])] = true
	s.update(w)
	s.update(w)
	assert_eq(s.get_child_count(), before + 1, "một đống đổ nát, không thêm lại mỗi khung")
	s.free()




## D-179 (lỗi chơi thử D-178: "đá đi xuyên được"): đá viền bục đặt tâm ngay trên mép vùng chặn nên nửa hòn đá
## nằm ngoài, đi xuyên qua được. Đá viền (xa nước) phải nằm hẳn trong bục rừng.
func test_D_179_plateau_rim_rocks_inside_blocked_area() -> void:
	var layout: MapLayout = load(MAP_PATH) as MapLayout
	var rocks: int = 0
	for it: Array in Terrain3D.items():
		if not [&"rock_tall", &"rock_wide", &"rock_low"].has(StringName(it[0])):
			continue
		var p: Vector2 = Vector2(float(it[1]), float(it[2]))
		if _near_water(layout, p, 400.0):
			continue  # đá bờ sông (decor_place.river) lún nửa xuống nước
		rocks += 1
		var inside: bool = false
		for shape: MapShape in layout.forest_shapes + layout.rock_shapes + layout.cliff_shapes:  # D-308: tường bãi đấu
			inside = inside or Geometry2D.is_point_in_polygon(p, shape.outer)
		assert_true(inside, "đá viền tại %s nằm trong bục / khối đá" % p)
	assert_true(rocks > 300, "bục có viền đá (%d)" % rocks)


static func _near_water(layout: MapLayout, p: Vector2, r: float) -> bool:
	for shape: MapShape in layout.water_shapes:
		var poly: PackedVector2Array = shape.outer
		for i: int in poly.size():
			if Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()]).distance_to(p) < r:
				return true
	return false


## D-197: rìa map (MAP-12) là vực kiểu Liên Quân — mặt đất 3D không phủ rìa (đất ở đó là vực), lan can đá
## chạy dọc mép đi được, không còn rào thấp + khe trước tường (D-195 lỗi chơi thử: tưởng blink vào được).
func test_D_197_edge_is_abyss_not_ground() -> void:
	var layout: MapLayout = load(MAP_PATH) as MapLayout
	var size: Vector2 = layout.world_size()
	var edge_points: Array[Vector2] = [Vector2(150, size.y * 0.3), Vector2(size.x - 150, size.y * 0.7)]
	for p: Vector2 in edge_points:
		assert_false(_in_tris(Terrain3D.decor()["ground"], p), "rìa map tại %s không có mặt đất" % p)
		assert_true(_in_tris(Terrain3D.decor()["abyss"], p), "rìa map tại %s là vực" % p)
	assert_true(_in_tris(Terrain3D.decor()["ground"], layout.tower_points[0]), "chân trụ có mặt đất")


func test_D_197_parapet_along_edge() -> void:
	var n: int = 0
	for it: Array in Terrain3D.items():
		n += 1 if String(it[0]) == "parapet" else 0
	assert_true(n > 100, "lan can dọc mép vực (%d đoạn)" % n)
	assert_true(ResourceLoader.exists(Terrain3D.texture(String(ModelLibrary.scenery()["style"]["abyss"]["floor"])).resource_path), "có ảnh đáy vực")


static func _in_tris(tris: Array, p: Vector2) -> bool:
	for t: Array in tris:
		if Geometry2D.point_is_inside_triangle(p, Vector2(t[0], t[1]), Vector2(t[2], t[3]), Vector2(t[4], t[5])):
			return true
	return false


## D-198 (lỗi chơi thử: đầu sông lên top nhìn chặn mà đi được): đá cuội bờ sông chỉ nằm trong vùng chặn thật.
func test_D_198_river_boulders_inside_blocked_area() -> void:
	var layout: MapLayout = load(MAP_PATH) as MapLayout
	var n: int = 0
	for it: Array in Terrain3D.items():
		if not String(it[0]).begins_with("boulder"):
			continue
		n += 1
		var p: Vector2 = Vector2(float(it[1]), float(it[2]))
		var inside: bool = false
		for poly: PackedVector2Array in layout.collision_polygons:
			inside = inside or Geometry2D.is_point_in_polygon(p, poly)
		assert_true(inside, "đá cuội tại %s nằm trong vùng chặn" % p)
	assert_true(n > 20, "bờ sông có đá (%d)" % n)


## D-221: fountain 3D ở fountain_point mỗi phe, ảnh màu theo phe, bậc thềm (mặt +Z) quay về nhà chính.
func test_D_221_fountain_per_team_faces_core() -> void:
	var layout: MapLayout = load(MAP_PATH) as MapLayout
	var s: Scenery3D = Scenery3D.new()
	s.add_fountains(layout)
	assert_eq(s.get_child_count(), 2, "mỗi phe một fountain")
	for team: int in [0, 1]:
		var n: Node3D = s.get_child(team) as Node3D
		var at: Vector2 = layout.fountain_point(team)
		assert_true(Vector2(n.position.x, n.position.z).distance_to(at * MatchView3D.S) < 3.0, "đặt ở fountain_point")
		var to_core: Vector2 = (layout.core_point(team) - at).normalized()
		var front: Vector3 = n.basis * Vector3(0, 0, 1)
		assert_true(Vector2(front.x, front.z).normalized().dot(to_core) > 0.99, "mặt trước quay về nhà chính")
		var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
		var tex: Texture2D = (mi.get_active_material(0) as StandardMaterial3D).albedo_texture
		assert_true(tex.resource_path.ends_with(("_blue" if team == 0 else "_red") + ".jpg"), "ảnh màu phe %d" % team)
	s.free()


## D-310, D-314: rào base / fountain (MAP-09, MAP-10) dựng bằng lan can đá như rìa map (`parapet`), dọc đúng đường rào
## (nằm trên vật cản rào — trông chặn thì chặn); không còn rào cũ / tường + cột Tripo.
func test_D_314_base_fences_are_parapets_on_fence_obstacle() -> void:
	var layout: MapLayout = load(MAP_PATH) as MapLayout
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/clashborn_map.json"))
	var fences: Array = (json["render"]["rock_lines"] as Array).filter(func(l: Dictionary) -> bool: return l.get("kind") == "fence")
	var on_fence: int = 0
	for it: Array in Terrain3D.items():
		var kind: String = String(it[0])
		assert_false(kind == "fence" or kind.begins_with("base_wall") or kind.begins_with("base_pillar"), "không còn %s" % kind)
		var p: Vector2 = Vector2(float(it[1]), float(it[2]))
		if kind != "parapet" or not _near_line(fences, p, 10.0):
			continue
		on_fence += 1
		var inside: bool = false
		for poly: PackedVector2Array in layout.collision_polygons:
			inside = inside or Geometry2D.is_point_in_polygon(p, poly)
		assert_true(inside, "lan can rào tại %s nằm trên vật cản" % p)
	assert_true(on_fence > 50, "rào base / fountain là lan can (%d đoạn)" % on_fence)


static func _near_line(lines: Array, p: Vector2, r: float) -> bool:
	for l: Dictionary in lines:
		var pts: Array = l["points"]
		for k: int in pts.size() - 1:
			var a: Vector2 = Vector2(pts[k][0], pts[k][1])
			if Geometry2D.get_closest_point_to_segment(p, a, Vector2(pts[k + 1][0], pts[k + 1][1])).distance_to(p) < r:
				return true
	return false


## D-310: nền đất cao lát đá (mặt nạ base R) thay đất nện một màu; sân lát kín quanh nhà chính / fountain.
## D-313: không còn vòng viền sân (người chơi: xấu) — kênh G là rêu loang quanh chân mọi trụ.
func test_D_310_base_ground_paved_D_313_moss_round_towers() -> void:
	var layout: MapLayout = load(MAP_PATH) as MapLayout
	var img: Image = Terrain3D.base_image()
	var rect: Rect2 = Terrain3D.mask_rect()
	var at: Callable = func(p: Vector2) -> Color:
		var uv: Vector2 = (p - rect.position) / rect.size * Vector2(img.get_size())
		return img.get_pixelv(Vector2i(uv))
	for team: int in [0, 1]:
		for p: Vector2 in [layout.core_point(team), layout.fountain_point(team)]:
			assert_true(at.call(p).r > 0.9, "sân quanh %s lát đá" % p)
			assert_true(Terrain3D.mask_image().get_pixelv(Vector2i((p - rect.position) / rect.size * Vector2(img.get_size()))).r < 0.1, "base không còn đất nện tại %s" % p)
		var ring: bool = false
		for k: int in 16:  # quanh fountain không có trụ → kênh G phải trống (không còn vòng viền sân)
			ring = ring or at.call(layout.fountain_point(team) + Vector2(330, 0).rotated(k * TAU / 16)).g > 0.5
		assert_false(ring, "không còn vòng viền quanh fountain phe %d" % team)
	for p: Vector2 in layout.tower_points:
		var moss: bool = false
		for k: int in 16:
			moss = moss or at.call(p + Vector2(110, 0).rotated(k * TAU / 16)).g > 0.5
		assert_true(moss, "có rêu quanh chân trụ %s" % p)
	assert_true(at.call(layout.world_size() * 0.5).r < 0.1, "giữa map không lát đá base")


## D-312: ven lane có cụm cỏ / dương xỉ xanh / đá nhỏ dọc mép đất (ảnh mẫu lane), không nằm giữa lane đi lại.
func test_D_312_lane_edges_have_plants_not_on_lane() -> void:
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/clashborn_map.json"))
	var half: float = float(json["lane_width"]) * 0.5
	var ferns: int = 0
	for it: Array in Terrain3D.items():
		if String(it[0]) != "plant_green":
			continue
		ferns += 1
		var p: Vector2 = Vector2(float(it[1]), float(it[2]))
		for pts: Array in json["lanes"].values():
			for i: int in pts.size() - 1:
				var a: Vector2 = Vector2(pts[i][0], pts[i][1])
				var b: Vector2 = Vector2(pts[i + 1][0], pts[i + 1][1])
				assert_true(Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) > half, "dương xỉ tại %s không nằm trên lane" % p)
	assert_true(ferns > 50, "mép lane có dương xỉ (%d)" % ferns)


## D-313: lội sông — giữa sông là nước hẳn (đơn vị lún + vòng gợn), giữa lane trên cạn thì không.
func test_D_313_wading_only_in_river() -> void:
	var layout: MapLayout = load(MAP_PATH) as MapLayout
	var shape: MapShape = layout.water_shapes[0]
	var inner: Array[PackedVector2Array] = Geometry2D.offset_polygon(shape.outer, -400.0)
	assert_true(inner.size() > 0, "sông đủ rộng để có lõi")
	var c: Vector2 = Vector2.ZERO
	for p: Vector2 in inner[0]:
		c += p
	c /= inner[0].size()
	var deep: Vector2 = inner[0][0] if not Geometry2D.is_point_in_polygon(c, inner[0]) else c
	assert_true(Wading3D.wetness(deep) > 0.9, "giữa sông %s là nước" % deep)
	assert_eq(Wading3D.wetness(layout.tower_points[0]), 0.0, "chân trụ trên cạn")


## D-316: ảnh dữ liệu nước là RGB (R sâu, G bờ) — ảnh LA bị Vulkan (điện thoại) đọc khác OpenGL: sông trắng đục.
## Shader lấy màu đỉnh / màu MultiMesh phải qua srgb_in (Vulkan tuyến tính) — không thì đá / cây bạc màu trên điện thoại.
func test_D_316_water_data_rgb_and_vertex_colors_linearized() -> void:
	assert_eq(Terrain3D.depth_image().get_format(), Image.FORMAT_RGB8, "ảnh nước RGB, không LA")
	for path: String in ["res://view/three/kit.gdshader", "res://view/three/kit_tex.gdshader", "res://view/three/ground_shapes.gdshader"]:
		var code: String = FileAccess.get_file_as_string(path)
		assert_true(code.contains("srgb.gdshaderinc") and not code.contains("ALBEDO = COLOR.rgb"), "%s đổi màu đỉnh sang tuyến tính" % path)


## D-317: mỗi loại trại có đồ riêng (pha lê trại lớn, totem + lửa trại trại pháp sư); đồ cao (totem, pha lê) nằm trong
## vùng chặn (trông chặn thì chặn, D-179); khoảng rừng trống có cụm trang trí thấp (hoa, nấm, gốc cây, gỗ đổ).
func test_D_317_camp_props_and_open_area_clutter() -> void:
	var layout: MapLayout = load(MAP_PATH) as MapLayout
	var seen: Dictionary = {}
	for it: Array in Terrain3D.items():
		var kind: String = String(it[0])
		seen[kind] = int(seen.get(kind, 0)) + 1
		if kind == "totem" or kind == "crystals":
			var p: Vector2 = Vector2(float(it[1]), float(it[2]))
			var inside: bool = false
			for poly: PackedVector2Array in layout.collision_polygons:
				inside = inside or Geometry2D.is_point_in_polygon(p, poly)
			assert_true(inside, "%s tại %s nằm trong vùng chặn" % [kind, p])
	for kind: String in ["crystals", "totem", "campfire", "bones", "flowers", "stump", "log", "mushrooms"]:
		assert_true(int(seen.get(kind, 0)) > 3, "có %s (%d)" % [kind, int(seen.get(kind, 0))])
