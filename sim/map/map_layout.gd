class_name MapLayout
extends Resource
## Bản đồ trong tọa độ thế giới (MAP-01, MAP-02). Mọi dữ liệu từ một file JSON do
## tools/map_build/build_map.py tạo, nên hình vẽ, vật cản và tìm đường không thể lệch
## nhau. File .tres chỉ đặt `data_path`; setter nạp JSON ngay.

const LANES: PackedStringArray = ["TOP", "MID", "BOT"]
const TOWER_LANES: PackedStringArray = ["TOP", "MID", "BOT", "BASE"]
## Hằng số kiểm tra lúc dựng map (không phải số gameplay): điểm lane phải cách vật
## cản ít nhất chừng này, fountain phải có khoảng trống chừng này.
const MIN_LANE_CLEARANCE: float = 40.0
const MIN_FOUNTAIN_CLEARANCE: float = 150.0

@export_file("*.json") var data_path: String = "":
	set(value):
		data_path = value
		if not value.is_empty():
			_load(value)

var load_errors: PackedStringArray = PackedStringArray()
var lane_width: float = 0.0
var nav_cell: float = 0.0

# Công trình. Các mảng dùng chung chỉ số: tower_ids[i] ở tower_points[i].
var tower_ids: PackedStringArray = PackedStringArray()
var tower_teams: PackedInt32Array = PackedInt32Array()
var tower_lanes: PackedStringArray = PackedStringArray()
var tower_tiers: PackedInt32Array = PackedInt32Array()
var tower_points: PackedVector2Array = PackedVector2Array()
## T2/T3: mọi trụ trong danh sách phải đổ. T4: một trụ bất kỳ trong danh sách đổ.
var tower_prerequisites: Array[PackedStringArray] = []
var core_points: PackedVector2Array = PackedVector2Array()
var fountain_points: PackedVector2Array = PackedVector2Array()

# Lane, lưu theo chiều Blue → Red; route() đảo cho Red.
var lanes: Dictionary[String, PackedVector2Array] = {}
var lane_spawns: Array[Dictionary] = [{}, {}]  # đội → {lane: Vector2}

# Rừng. camp_sides: 0 rừng Blue, 1 rừng Red, -1 dùng chung (boss pit).
var camp_ids: PackedStringArray = PackedStringArray()
var camp_kinds: PackedStringArray = PackedStringArray()
var camp_sides: PackedInt32Array = PackedInt32Array()
var camp_points: PackedVector2Array = PackedVector2Array()

# Vùng và địa hình.
var base_polygons: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array()]
var ramp_points: PackedVector2Array = PackedVector2Array()
var ramp_angles: PackedFloat32Array = PackedFloat32Array()
var forest_shapes: Array[MapShape] = []
var cliff_shapes: Array[MapShape] = []
var water_shapes: Array[MapShape] = []
var collision_polygons: Array[PackedVector2Array] = []
## VIS-06: bụi cỏ.
var bushes: MapBushes = MapBushes.new()
## M5.6: điểm có tên cho map dev (khe, lối…), chỉ để hiển thị.
var landmark_names: PackedStringArray = PackedStringArray()
var landmark_points: PackedVector2Array = PackedVector2Array()
## D-81: shop ẩn (S1, S1').
var shop_names: PackedStringArray = PackedStringArray()
var shop_points: PackedVector2Array = PackedVector2Array()

# Trường khoảng trống: khoảng cách (đơn vị thế giới) từ mỗi pixel tới vật cản gần nhất.
var clearance_bytes: PackedByteArray = PackedByteArray()
var clearance_size: Vector2i = Vector2i.ZERO
var clearance_pixel: float = 1.0
var clearance_unit: float = 1.0

var _size: Vector2 = Vector2.ZERO


static func from_file(path: String) -> MapLayout:
	var layout: MapLayout = MapLayout.new()
	layout.data_path = path
	return layout


# ------------------------------------------------------------------ truy vấn

func world_size() -> Vector2:
	return _size


func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, _size)


func route(lane: String, team: int) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array(lanes.get(lane, PackedVector2Array()))
	if team == 1:
		result.reverse()
	return result


func fountain_point(team: int) -> Vector2:
	return fountain_points[clampi(team, 0, fountain_points.size() - 1)]


func core_point(team: int) -> Vector2:
	return core_points[clampi(team, 0, core_points.size() - 1)]


## Nơi lính của một lane xuất hiện (ngay sau T3 của lane đó).
func lane_spawn_point(team: int, lane: String) -> Vector2:
	return lane_spawns[team].get(lane, fountain_point(team))


func tower_index(tower_id: String) -> int:
	return tower_ids.find(tower_id)


func tower_point(tower_id: String) -> Vector2:
	return tower_points[tower_index(tower_id)]


func is_in_base(point: Vector2, team: int) -> bool:
	return Geometry2D.is_point_in_polygon(point, base_polygons[team])


## Khoảng cách từ `point` tới vật cản địa hình gần nhất (rừng, vách, mép map).
## Trụ không phải địa hình; MapNavigation tự tính thân trụ.
func clearance_at(point: Vector2) -> float:
	if clearance_bytes.is_empty() or not point.is_finite():
		return 0.0
	var x: int = floori(point.x / clearance_pixel)
	var y: int = floori(point.y / clearance_pixel)
	if x < 0 or y < 0 or x >= clearance_size.x or y >= clearance_size.y:
		return 0.0
	return float(clearance_bytes[y * clearance_size.x + x]) * clearance_unit


## Điểm gần `point` nhất mà một vật bán kính `radius` đứng được (chỉ xét địa hình).
## Tìm theo vòng tròn mở rộng; không thấy thì trả `point`.
func nearest_walkable(point: Vector2, radius: float, max_distance: float = 1600.0) -> Vector2:
	return MapLayout.search_rings(point, clearance_pixel, max_distance,
		func(candidate: Vector2) -> bool: return clearance_at(candidate) >= radius)


## Tìm điểm gần nhất thỏa `accept` trên các vòng tròn cách nhau `step`.
static func search_rings(point: Vector2, step: float, max_distance: float, accept: Callable) -> Vector2:
	var ring: float = 0.0
	while ring <= max_distance:
		var samples: int = maxi(1, int(TAU * ring / step))
		for i: int in range(samples):
			var candidate: Vector2 = point + Vector2.from_angle(TAU * i / samples) * ring
			if accept.call(candidate):
				return candidate
		ring += step
	return point


func validation_errors() -> PackedStringArray:
	return MapValidator.errors(self)


# ------------------------------------------------------------------ nạp JSON

func _load(path: String) -> void:
	load_errors.clear()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		load_errors.append("Không đọc được JSON map: " + path)
		return
	var d: Dictionary = data
	_size = _vec(d["world_size"])
	lane_width = float(d["lane_width"])
	nav_cell = float(d["nav_cell"])
	_load_towers(d["towers"])
	core_points = _points(d["cores"])
	fountain_points = _points(d["fountains"])
	_load_lanes(d["lanes"], d["lane_spawns"])
	_load_camps(d["camps"])
	_load_terrain(d)
	_load_clearance(d["clearance"], path)


func _load_towers(towers: Array) -> void:
	tower_ids.clear(); tower_teams.clear(); tower_lanes.clear()
	tower_tiers.clear(); tower_points.clear(); tower_prerequisites.clear()
	for tower: Dictionary in towers:
		var tier: int = int(tower["tier"])
		tower_ids.append(tower["id"])
		tower_teams.append(int(tower["team"]))
		tower_lanes.append(tower["lane"])
		tower_tiers.append(tier)
		tower_points.append(_vec(tower["pos"]))
		var requires: Dictionary = tower.get("requires", {})
		tower_prerequisites.append(PackedStringArray(requires.get("any" if tier == 4 else "all", [])))


func _load_lanes(lane_data: Dictionary, spawn_data: Dictionary) -> void:
	lanes.clear()
	for lane: String in lane_data:
		lanes[lane] = _points(lane_data[lane])
	lane_spawns = [{}, {}]
	for team_key: String in spawn_data:
		var spawns: Dictionary = spawn_data[team_key]
		for lane: String in spawns:
			lane_spawns[int(team_key)][lane] = _vec(spawns[lane])


func _load_camps(camps: Array) -> void:
	camp_ids.clear(); camp_kinds.clear(); camp_sides.clear(); camp_points.clear()
	for camp: Dictionary in camps:
		camp_ids.append(camp["id"])
		camp_kinds.append(camp["kind"])
		camp_sides.append(int(camp["side"]))
		camp_points.append(_vec(camp["pos"]))


func _load_terrain(d: Dictionary) -> void:
	base_polygons = [PackedVector2Array(), PackedVector2Array()]
	for base: Dictionary in d["bases"]:
		base_polygons[int(base["team"])] = _points(base["polygon"])
	ramp_points.clear(); ramp_angles.clear()
	for ramp: Dictionary in d.get("ramps", []):
		ramp_points.append(_vec(ramp["pos"]))
		ramp_angles.append(float(ramp.get("angle", 0.0)))
	var render: Dictionary = d["render"]
	forest_shapes = _shapes(render["forest"])
	cliff_shapes = _shapes(render["cliffs"])
	water_shapes = _shapes(render["water"])
	bushes.load_from(d.get("bushes", []))
	landmark_names.clear(); landmark_points.clear()
	shop_names.clear(); shop_points.clear()
	for shop: Dictionary in d.get("shops", []):
		shop_names.append(shop["name"])
		shop_points.append(_vec(shop["pos"]))
	for mark: Dictionary in d.get("landmarks", []):
		landmark_names.append(mark["name"])
		landmark_points.append(_vec(mark["pos"]))
	collision_polygons.clear()
	for polygon: Array in d["collision"]:
		collision_polygons.append(_points(polygon))


## Nhúng base64 trong JSON (hàng nối hàng, 1 byte mỗi pixel) để map không phụ thuộc
## bước import của Godot (lỗi crash ở v1).
func _load_clearance(c: Dictionary, path: String) -> void:
	clearance_pixel = float(c["pixel_world"])
	clearance_unit = float(c["unit_world"])
	clearance_size = Vector2i(int(c["width"]), int(c["height"]))
	clearance_bytes = Marshalls.base64_to_raw(str(c.get("bytes_base64", "")))
	if clearance_bytes.size() != clearance_size.x * clearance_size.y:
		load_errors.append("Sai kích thước trường khoảng trống trong " + path)


static func _vec(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


static func _points(values: Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for value: Array in values:
		result.append(_vec(value))
	return result


static func _shapes(values: Array) -> Array[MapShape]:
	var result: Array[MapShape] = []
	for value: Dictionary in values:
		var shape: MapShape = MapShape.new()
		shape.outer = _points(value["outer"])
		for hole: Array in value.get("holes", []):
			shape.holes.append(_points(hole))
		result.append(shape)
	return result
