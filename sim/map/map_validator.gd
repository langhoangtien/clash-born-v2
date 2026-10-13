class_name MapValidator
extends RefCounted
## Kiểm tra dữ liệu map lúc nạp (MAP-02). Tách khỏi MapLayout cho gọn file.


static func errors(m: MapLayout) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(m.load_errors)
	var size: Vector2 = m.world_size()
	if size.x <= 0 or size.y <= 0:
		out.append("Kích thước map không hợp lệ")
	if m.fountain_points.size() != 2 or m.core_points.size() != 2:
		out.append("Cần đúng 2 fountain và 2 nhà chính")
	_check_towers(m, out)
	_check_lanes(m, out)
	_check_bases(m, out)
	if m.clearance_bytes.is_empty() or m.clearance_bytes.size() != m.clearance_size.x * m.clearance_size.y:
		out.append("Trường khoảng trống không hợp lệ")
	return out


static func _check_towers(m: MapLayout, out: PackedStringArray) -> void:
	var count: int = m.tower_ids.size()
	if m.tower_teams.size() != count or m.tower_lanes.size() != count or m.tower_tiers.size() != count \
			or m.tower_points.size() != count or m.tower_prerequisites.size() != count:
		out.append("Các mảng trụ lệch kích thước")
		return
	var seen: Dictionary[String, bool] = {}
	for i: int in range(count):
		var id: String = m.tower_ids[i]
		if id.is_empty() or seen.has(id):
			out.append("Id trụ rỗng hoặc trùng: " + id)
		seen[id] = true
		if not MapLayout.TOWER_LANES.has(m.tower_lanes[i]):
			out.append("Lane của trụ sai: " + m.tower_lanes[i])
		if m.tower_tiers[i] < 1 or m.tower_tiers[i] > 4:
			out.append("Bậc trụ sai: " + id)
		if not m.world_rect().has_point(m.tower_points[i]):
			out.append("Trụ nằm ngoài map: " + id)
	for prerequisites: PackedStringArray in m.tower_prerequisites:
		for need: String in prerequisites:
			if not m.tower_ids.has(need):
				out.append("Điều kiện trụ không tồn tại: " + need)


static func _check_lanes(m: MapLayout, out: PackedStringArray) -> void:
	for lane: String in MapLayout.LANES:
		var points: PackedVector2Array = m.lanes.get(lane, PackedVector2Array())
		if points.size() < 2:
			out.append("Thiếu lane " + lane)
		for point: Vector2 in points:
			if m.clearance_at(point) < MapLayout.MIN_LANE_CLEARANCE:
				out.append("Điểm lane %s %s quá sát vật cản" % [lane, point])
		for team: int in range(2):
			if not m.lane_spawns[team].has(lane):
				out.append("Thiếu điểm sinh lính %d/%s" % [team, lane])


static func _check_bases(m: MapLayout, out: PackedStringArray) -> void:
	if m.fountain_points.size() != 2:
		return
	for team: int in range(2):
		if m.base_polygons[team].size() < 3:
			out.append("Thiếu vùng base đội %d" % team)
		elif not m.is_in_base(m.fountain_point(team), team):
			out.append("Fountain nằm ngoài base đội %d" % team)
		if m.clearance_at(m.fountain_point(team)) < MapLayout.MIN_FOUNTAIN_CLEARANCE:
			out.append("Fountain quá chật: đội %d" % team)
