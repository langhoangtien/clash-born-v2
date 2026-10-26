extends RefCounted
## Vẽ tạm MapLayout bằng hình phẳng (mang từ v1). Ảnh thật (art_inbox/01_env) thay
## vào ở mốc đồ họa. Chỉ vẽ, không có logic. Dùng qua preload, không class_name.

const VOID := Color("0c1719")
const FLOWERS := [Color("f3e7c4"), Color("f2cf55"), Color("e9a7c0")]
const PEBBLE := Color("9c9a8c")
const PEBBLE_LIGHT := Color("c4c2b4")
const GROUND := Color("627f38")
const GROUND_DARK := Color("4e6b2b")
const GROUND_LIGHT := Color("7a9644")
const BASE_FLOOR := [Color("4f7487"), Color("86625c")]
const BASE_TILE := [Color("5b8296"), Color("94706a")]
const BASE_EDGE := [Color("7fb6e6"), Color("e99a92")]
const LANE := Color("dfbd85")
const LANE_EDGE := Color("a99a5c")
const LANE_DARK := Color("c49f68")
const WATER_DEEP := Color("2b97a8")
const WATER_LIGHT := Color("47b6b4")
const WATER_BANK := Color("6d6b4c")
const FOREST_SHADOW := Color("4c6a2a")
const FOREST_BODY := Color("4b6829")
const FOREST_CANOPY := Color("486427")
const FOREST_LIGHT := Color("456025")
const CLIFF := Color("5d6b3a")
const CLIFF_TOP := Color("6f7a48")
const RAMP := Color("bfae80")
const RAMP_LINE := Color("9d8c60")
const CAMP_CLEARING := Color("617f37")
const BUSH := Color("6e9236")
const BUSH_DARK := Color("557829")
const BUSH_LIGHT := Color("9cbd55")

## Nền, base, sông, dốc, lane: mọi thứ đơn vị đi lên được.
static func paint_ground(ci: CanvasItem, layout: MapLayout, detail: bool = true, fountain_radius: float = 0.0) -> void:
	var size := layout.world_size()
	ci.draw_rect(Rect2(Vector2.ZERO, size), GROUND)
	if detail:
		# Vệt nền đậm nhạt cố định (seed riêng của VIEW) để vùng trống không phẳng lì.
		var rng := RandomNumberGenerator.new()
		rng.seed = 7341
		for index in range(110):
			var center := Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
			ci.draw_circle(center, rng.randf_range(160, 420), Color(GROUND_DARK if index % 2 == 0 else GROUND_LIGHT, 0.35))
		_paint_specks(ci, size, rng)
		for camp in layout.camp_points:
			ci.draw_circle(camp, 210, CAMP_CLEARING)
	for team in range(2):
		_paint_base(ci, layout, team, detail)
	_paint_water(ci, layout, detail)
	if fountain_radius > 0.0:
		_paint_fountains(ci, layout, fountain_radius)
	if detail:
		_paint_ramps(ci, layout)
	var lane_width := layout.lane_width
	for lane: String in layout.lanes:
		var points: PackedVector2Array = layout.lanes[lane]
		if detail: _thick_line(ci, points, LANE_EDGE, lane_width + 36)
		_thick_line(ci, points, LANE, lane_width)
		if detail: _paint_lane_wear(ci, points, lane_width)


## Vùng hồi máu fountain: nền đá sáng màu đội, viền rõ để biết ranh giới.
static func _paint_fountains(ci: CanvasItem, layout: MapLayout, radius: float) -> void:
	for team in range(2):
		var c := layout.fountain_point(team)
		ci.draw_circle(c, radius, Color(BASE_EDGE[team], 0.16))
		ci.draw_arc(c, radius - 14, 0, TAU, 96, Color(BASE_EDGE[team], 0.95), 20, true)
		ci.draw_arc(c, radius - 40, 0, TAU, 96, Color(1, 1, 1, 0.35), 6, true)
		for k in range(24):  # vạch đá dọc viền
			var a := TAU * k / 24.0
			ci.draw_line(c + Vector2.from_angle(a) * (radius - 30), c + Vector2.from_angle(a) * (radius + 2), Color(BASE_TILE[team], 0.9), 5, true)


## Hoa nhỏ và sỏi rải trên cỏ (nướng một lần; lane, rừng vẽ đè lên sau).
static func _paint_specks(ci: CanvasItem, size: Vector2, rng: RandomNumberGenerator) -> void:
	for index in range(1400):
		var at := Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
		var color: Color = FLOWERS[rng.randi() % FLOWERS.size()]
		for k in range(rng.randi_range(2, 5)):
			ci.draw_circle(at + Vector2(rng.randf_range(-22, 22), rng.randf_range(-14, 14)), rng.randf_range(4, 7), color)
	for index in range(700):
		var at := Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
		var r := rng.randf_range(7, 15)
		ci.draw_circle(at + Vector2(0, r * 0.35), r, Color(0.2, 0.25, 0.1, 0.35))
		ci.draw_circle(at, r, PEBBLE)
		ci.draw_circle(at - Vector2(r, r) * 0.3, r * 0.45, PEBBLE_LIGHT)


## Lane: mảng đất đậm nhạt và phiến đá mờ dọc đường.
static func _paint_lane_wear(ci: CanvasItem, points: PackedVector2Array, width: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(points[0].x + points[0].y * 3.0)
	for i in range(points.size() - 1):
		var steps := int(points[i].distance_to(points[i + 1]) / 90.0)
		for k in range(steps):
			var at := points[i].lerp(points[i + 1], (k + rng.randf()) / maxi(1, steps))
			var side := (points[i + 1] - points[i]).normalized().orthogonal() * rng.randf_range(-0.4, 0.4) * width
			ci.draw_circle(at + side, rng.randf_range(40, 90), Color(LANE_DARK, 0.22))
			if rng.randf() < 0.5:
				ci.draw_circle(at - side, rng.randf_range(25, 45), Color(1, 1, 1, 0.10))


static func _paint_base(ci: CanvasItem, layout: MapLayout, team: int, detail: bool) -> void:
	var base := layout.base_polygons[team]
	if base.size() < 3: return
	ci.draw_colored_polygon(base, BASE_FLOOR[team])
	if not detail: return
	for inner in Geometry2D.offset_polygon(base, -160, Geometry2D.JOIN_ROUND):
		ci.draw_colored_polygon(inner, BASE_TILE[team])
	_outline(ci, base, Color(BASE_EDGE[team], 0.55), 14)
	# Vòng sân quanh nhà chính cho base trông như khu xây dựng.
	for radius in [260.0, 420.0]:
		ci.draw_arc(layout.core_point(team), radius, 0, TAU, 72, Color(BASE_EDGE[team], 0.22), 10, true)


static func _paint_water(ci: CanvasItem, layout: MapLayout, detail: bool) -> void:
	for shape: MapShape in layout.water_shapes:
		ci.draw_colored_polygon(shape.outer, WATER_DEEP)
		if detail:
			_outline(ci, shape.outer, WATER_BANK, 22)
			for inner in Geometry2D.offset_polygon(shape.outer, -70, Geometry2D.JOIN_ROUND):
				ci.draw_colored_polygon(inner, WATER_LIGHT)


## Dốc: vài bậc thang cắt ngang khe hở của vách đá.
static func _paint_ramps(ci: CanvasItem, layout: MapLayout) -> void:
	for index in range(layout.ramp_points.size()):
		var along := Vector2.from_angle(layout.ramp_angles[index])
		var across := along.orthogonal()
		var center := layout.ramp_points[index]
		var corners := PackedVector2Array([
			center - along * 150 - across * 95, center + along * 150 - across * 95,
			center + along * 150 + across * 95, center - along * 150 + across * 95])
		ci.draw_colored_polygon(corners, RAMP)
		for step in [-60.0, -20.0, 20.0, 60.0]:
			ci.draw_line(center + across * step - along * 140, center + across * step + along * 140, RAMP_LINE, 9, true)

## Vách đá và rừng: mọi thứ chặn đường.
static func paint_obstacles(ci: CanvasItem, layout: MapLayout, detail: bool = true) -> void:
	for shape: MapShape in layout.cliff_shapes:
		ci.draw_colored_polygon(shape.outer, CLIFF)
		if detail: _outline(ci, shape.outer, CLIFF_TOP, 8)
	for shape: MapShape in layout.forest_shapes:
		ci.draw_colored_polygon(shape.outer, FOREST_BODY)
		if detail:
			for inner in Geometry2D.offset_polygon(shape.outer, -38, Geometry2D.JOIN_ROUND):
				ci.draw_colored_polygon(inner, FOREST_CANOPY)
				for top in Geometry2D.offset_polygon(inner, -70, Geometry2D.JOIN_ROUND):
					ci.draw_set_transform(Vector2(-14, -18))
					ci.draw_colored_polygon(top, FOREST_LIGHT)
					ci.draw_set_transform(Vector2.ZERO)
		for hole in shape.holes:
			ci.draw_colored_polygon(hole, GROUND)

static func _outline(ci: CanvasItem, polygon: PackedVector2Array, color: Color, width: float) -> void:
	if polygon.size() < 2: return
	var closed := PackedVector2Array(polygon)
	closed.append(polygon[0])
	ci.draw_polyline(closed, color, width, true)

static func _thick_line(ci: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2: return
	ci.draw_polyline(points, color, width, true)
	# Round joints and caps: draw_polyline has square joints only.
	for point in points: ci.draw_circle(point, width * 0.5, color)


## VIS-06: bụi cỏ — khối cỏ cao, viền đậm; `detail` thêm các ngọn cỏ.
static func paint_bushes(ci: CanvasItem, layout: MapLayout, detail: bool = true) -> void:
	for poly: PackedVector2Array in layout.bushes.polygons:
		ci.draw_colored_polygon(poly, BUSH)
		var closed: PackedVector2Array = poly.duplicate()
		closed.append(poly[0])
		ci.draw_polyline(closed, BUSH_DARK, 10.0 if detail else 40.0, true)
		if not detail:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = int(poly[0].x * 31.0 + poly[0].y)
		var box := Rect2(poly[0], Vector2.ZERO)
		for p in poly:
			box = box.expand(p)
		for i in range(60):
			var at := box.position + Vector2(rng.randf(), rng.randf()) * box.size
			if Geometry2D.is_point_in_polygon(at, poly):
				var h := rng.randf_range(18.0, 34.0)
				ci.draw_line(at, at + Vector2(-6, -h), BUSH_DARK, 4.0, true)
				ci.draw_line(at + Vector2(4, 0), at + Vector2(6, -h * 0.9), BUSH_LIGHT, 3.0, true)


## SHOP-02: shop ẩn — mái nhà vàng và vòng bán kính mua.
static func paint_shops(ci: CanvasItem, layout: MapLayout, radius: float, detail: bool = true) -> void:
	for p: Vector2 in layout.shop_points:
		if detail:
			ci.draw_arc(p, radius, 0, TAU, 64, Color(1.0, 0.8, 0.2, 0.35), 6.0, true)
		ci.draw_rect(Rect2(p - Vector2(50, 30), Vector2(100, 70)), Color("8a5a2b"))
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-70, -30), p + Vector2(70, -30), p + Vector2(0, -90)]), Color("d9a63a"))
		ci.draw_rect(Rect2(p - Vector2(50, 30), Vector2(100, 70)), Color(0, 0, 0, 0.7), false, 6.0)
