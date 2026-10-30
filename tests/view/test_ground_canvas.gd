extends TestCase
## D-180: GroundCanvas — lệnh vẽ kiểu CanvasItem thành hình của MultiMesh (một hình mỗi vòng / đoạn thẳng,
## đa giác tách tam giác), toạ độ px thế giới đổi sang mét.


## Custom (kiểu, bán kính trong, góc đầu, độ mở) của hình `i`.
func _custom(c: GroundCanvas, i: int) -> Color:
	var d: PackedFloat32Array = c.shape(i)
	return Color(d[16], d[17], d[18], d[19])


## Biến đổi 3D của hình `i` (bộ đệm MultiMesh là hàng của ma trận 3×4).
func _xf(c: GroundCanvas, i: int) -> Transform3D:
	var d: PackedFloat32Array = c.shape(i)
	return Transform3D(Vector3(d[0], d[4], d[8]), Vector3(d[1], d[5], d[9]), Vector3(d[2], d[6], d[10]), Vector3(d[3], d[7], d[11]))


func test_D_180_arc_is_one_ring_shape() -> void:
	var c: GroundCanvas = GroundCanvas.new()
	c.begin()
	c.draw_arc(Vector2(100, 200), 50.0, 0.0, PI, 32, Color.RED, 10.0)
	assert_eq(c.shape_count(), 1)
	var d: Color = _custom(c, 0)
	assert_eq(d.r, GroundCanvas.DISC, "kiểu đĩa / vành")
	assert_near(d.g, 45.0 / 55.0, 0.001, "bán kính trong theo tỉ lệ")
	assert_near(d.a, PI, 0.001, "độ mở nửa vòng")
	var t: Transform3D = _xf(c, 0)
	assert_near(t.origin.x, 1.0, 0.001, "100 px = 1 m")
	assert_near(t.origin.z, 2.0, 0.001)
	assert_near(t.basis.x.x, 0.55, 0.001, "bán kính ngoài 55 px")
	c.free()


func test_D_180_rectangle_polygon_is_two_triangles() -> void:
	var c: GroundCanvas = GroundCanvas.new()
	c.begin()
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 50), Vector2(0, 50)]), Color.WHITE)
	assert_eq(c.shape_count(), 2)
	assert_eq(_custom(c, 0).r, GroundCanvas.TRI)
	c.free()


func test_D_180_begin_clears_previous_frame() -> void:
	var c: GroundCanvas = GroundCanvas.new()
	c.begin()
	c.draw_line(Vector2.ZERO, Vector2(100, 0), Color.WHITE, 4.0)
	c.draw_circle(Vector2.ZERO, 20.0, Color.WHITE)
	c.commit()
	assert_eq(c.multimesh.instance_count, 2)
	c.begin()
	c.commit()
	assert_eq(c.multimesh.instance_count, 0, "khung mới không còn hình cũ")
	c.free()


func test_D_180_transform_squashes_ellipse() -> void:
	var c: GroundCanvas = GroundCanvas.new()
	c.begin()
	c.draw_set_transform(Vector2(100, 100), 0.0, Vector2(1.0, 0.5))
	c.draw_circle(Vector2.ZERO, 100.0, Color.WHITE)
	var t: Transform3D = _xf(c, 0)
	assert_near(t.basis.x.x, 1.0, 0.001)
	assert_near(t.basis.z.z, 0.5, 0.001, "ép dọc theo draw_set_transform")
	assert_near(t.origin.x, 1.0, 0.001)
	c.free()
