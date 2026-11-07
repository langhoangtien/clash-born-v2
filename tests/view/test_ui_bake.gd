extends TestCase
## D-290: nút tròn dựng sẵn thành ảnh (1 lệnh vẽ thay vì 9) — ảnh giữ đúng hình của bản vẽ cũ.


func _px(img: Image, cell: int, r: float, at: Vector2) -> Color:
	var half: int = UiBake.half_cell(r)
	return img.get_pixel(cell * half * 2 + half + int(at.x), half + int(at.y))


func test_D_290_orb_texture_cached_per_radius() -> void:
	var a: Texture2D = UiBake.orb_texture(62.0)
	assert_true(a == UiBake.orb_texture(62.0), "cùng bán kính: dùng lại ảnh")
	assert_true(a != UiBake.orb_texture(56.0))
	assert_eq(a.get_width(), UiBake.half_cell(62.0) * 2 * UiBake.CELLS)


func test_D_290_orb_cells_match_old_drawing() -> void:
	var r: float = 62.0
	var img: Image = UiBake.orb_texture(r).get_image()
	assert_near(_px(img, UiBake.Cell.BODY, r, Vector2.ZERO).a, 1.0, 0.01, "thân đặc ở tâm")
	assert_near(_px(img, UiBake.Cell.BODY, r, Vector2(r + 3, 0)).a, 0.0, 0.01, "ngoài bán kính trong suốt")
	assert_near(_px(img, UiBake.Cell.LIGHT, r, Vector2.ZERO).a, 0.24, 0.01, "tâm sáng nhất: đĩa thứ 5 lightened 0,24")
	assert_near(_px(img, UiBake.Cell.LIGHT, r, Vector2(r * 0.93, 0)).a, 0.0, 0.01, "vành ngoài là màu gốc")
	var ring: Color = _px(img, UiBake.Cell.DECO_LIT, r, Vector2(r - 2.5, 0))
	assert_near(ring.a, 1.0, 0.02, "viền vàng đậm đặc")
	assert_near(ring.r, UiStyle.GOLD_DEEP.r, 0.02)
	assert_true(_px(img, UiBake.Cell.DECO_DIM, r, Vector2(r - 2.5, 0)).a < 0.7, "nút tối: viền mờ hơn")
	assert_true(_px(img, UiBake.Cell.DECO_LIT, r, Vector2(0, -r * 0.72)).a > 0.1, "vệt sáng cung trên")
	assert_near(_px(img, UiBake.Cell.DECO_LIT, r, Vector2(0, r * 0.72)).a, 0.0, 0.01, "không có ở dưới")
	assert_true(_px(img, UiBake.Cell.SHADOW, r, Vector2(0, r + 4)).a > 0.05, "bóng lệch xuống")


func test_D_290_baked_pngs_match_generator() -> void:
	for r: float in UiBake.RADII:
		assert_true(ResourceLoader.exists(UiBake.baked_path(r)), "thiếu ảnh dựng sẵn r=%s — chạy tools/ui/bake_orbs.gd" % r)
	var r0: float = 62.0
	var baked: Image = (load(UiBake.baked_path(r0)) as Texture2D).get_image()
	var fresh: Image = UiBake.orb_image(r0)
	assert_eq(baked.get_size(), fresh.get_size())
	for p: Vector2i in [Vector2i(70, 70), Vector2i(10, 70), Vector2i(200, 66), Vector2i(400, 20), Vector2i(560, 60)]:
		var a: Color = baked.get_pixelv(p)
		var b: Color = fresh.get_pixelv(p)
		assert_true(absf(a.a - b.a) < 0.02 and absf(a.r - b.r) < 0.02, "ảnh dựng sẵn cũ — chạy lại tools/ui/bake_orbs.gd (%s)" % p)
