extends RefCounted
## D-371: đặt ảnh concept cắt nền (cat_concept.py) đứng trong trận ở cỡ thật — ảnh đứng quay về camera như đơn vị chưa có
## mô hình (Actor3D._make_sprite), chiều cao = `height` của tướng trong units_3d.json × `scale` — để thử độ đọc ở góc trận
## trước khi dựng 3D. Kèm một trụ (mô hình thật) đứng cạnh để so cỡ.


static func place(parent: Node3D, dir: String, ids: PackedStringArray, at: Vector2, along: Vector2, gap: float, scale: float) -> void:
	for i: int in ids.size():
		var img: Image = Image.load_from_file(dir.path_join(ids[i] + ".png"))
		var tex: ImageTexture = ImageTexture.create_from_image(img)
		var h: float = float(ModelLibrary.unit(StringName(ids[i])).get("height", 1.3)) * scale
		var s: Sprite3D = Sprite3D.new()
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # quay thẳng về camera như ảnh đơn vị trong game (FIXED_Y bị nén dẹt quá)
		s.shaded = false
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		s.texture = tex
		s.pixel_size = h / tex.get_height()
		s.offset = Vector2(0, tex.get_height() * 0.5)
		var p: Vector2 = at + along * ((i - (ids.size() - 1) / 2.0) * gap)
		s.position = Vector3(p.x, 0, p.y) * MatchView3D.S
		parent.add_child(s)
		parent.add_child(_blob(s.position, h))


static func tower(parent: Node3D, at: Vector2) -> void:
	var cfg: Dictionary = ModelLibrary.config()["structures"]["tower_t1"]
	var n: Node3D = ModelLibrary.static_scene(cfg["model"], 0).instantiate() as Node3D
	ModelLibrary.apply_team_texture(n, cfg["model"], 0)
	var box: AABB = ModelLibrary.bounds(n)
	var k: float = float(cfg["height"]) / maxf(0.01, box.size.y)
	n.scale = Vector3.ONE * k
	n.position = Vector3(at.x, 0, at.y) * MatchView3D.S - Vector3(box.get_center().x, box.position.y, box.get_center().z) * k
	parent.add_child(n)


static func _blob(at: Vector3, h: float) -> Node3D:
	var b: MeshInstance3D = Look3D.blob(h)
	b.position += at
	return b
