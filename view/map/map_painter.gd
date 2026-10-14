extends RefCounted
## Vẽ tạm MapLayout bằng hình phẳng (mang từ v1). Ảnh thật (art_inbox/01_env) thay
## vào ở mốc đồ họa. Chỉ vẽ, không có logic. Dùng qua preload, không class_name.

const VOID := Color("0c1719")
const GROUND := Color("4b7b5d")
const GROUND_DARK := Color("416e53")
const BASE_FLOOR := [Color("4f7487"), Color("86625c")]
const BASE_TILE := [Color("5b8296"), Color("94706a")]
const BASE_EDGE := [Color("7fb6e6"), Color("e99a92")]
const LANE := Color("cdb88c")
const LANE_EDGE := Color("a08b62")
const WATER_DEEP := Color("2a7db0")
const WATER_LIGHT := Color("3f9ccc")
const WATER_BANK := Color("1d5a80")
const FOREST_SHADOW := Color("1b3d2c")
const FOREST_BODY := Color("255639")
const FOREST_CANOPY := Color("2f6a45")
const FOREST_LIGHT := Color("3d7f52")
const CLIFF := Color("263034")
const CLIFF_TOP := Color("4f5f63")
const RAMP := Color("7f9b82")
const RAMP_LINE := Color("63806a")
const CAMP_CLEARING := Color("446f53")
const BUSH := Color("6f9a3a")
const BUSH_DARK := Color("4e7428")
const BUSH_LIGHT := Color("94c05a")

## Nền, base, sông, dốc, lane: mọi thứ đơn vị đi lên được.
static func paint_ground(ci: CanvasItem, layout: MapLayout, detail: bool = true) -> void:
	var size := layout.world_size()
	ci.draw_rect(Rect2(Vector2.ZERO, size), GROUND)
	if detail:
		# Vệt nền đậm nhạt cố định (seed riêng của VIEW) để vùng trống không phẳng lì.
		var rng := RandomNumberGenerator.new()
		rng.seed = 7341
		for index in range(70):
			var center := Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
			ci.draw_circle(center, rng.randf_range(160, 420), Color(GROUND_DARK, 0.35))
		for camp in layout.camp_points:
			ci.draw_circle(camp, 210, CAMP_CLEARING)
	for team in range(2):
		_paint_base(ci, layout, team, detail)
	_paint_water(ci, layout, detail)
	if detail:
		_paint_ramps(ci, layout)
	var lane_width := layout.lane_width
	for lane: String in layout.lanes:
		var points: PackedVector2Array = layout.lanes[lane]
		if detail: _thick_line(ci, points, LANE_EDGE, lane_width + 36)
		_thick_line(ci, points, LANE, lane_width)
		if detail: _thick_line(ci, points, Color(1, 1, 1, 0.07), lane_width * 0.35)


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
		if detail:
			ci.draw_set_transform(Vector2(0, 26))
			ci.draw_colored_polygon(shape.outer, FOREST_SHADOW)
			ci.draw_set_transform(Vector2.ZERO)
		ci.draw_colored_polygon(shape.outer, FOREST_BODY)
		if detail:
			for inner in Geometry2D.offset_polygon(shape.outer, -38, Geometry2D.JOIN_ROUND):
				ci.draw_colored_polygon(inner, FOREST_CANOPY)
				for top in Geometry2D.offset_polygon(inner, -70, Geometry2D.JOIN_ROUND):
					ci.draw_set_transform(Vector2(-14, -18))
					ci.draw_colored_polygon(top, FOREST_LIGHT)
					ci.draw_set_transform(Vector2.ZERO)
			_outline(ci, shape.outer, FOREST_SHADOW, 10)
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
