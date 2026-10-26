class_name Mountains3D
extends RefCounted
## Núi đá (D-169, D-170): khối đá của map (`rock_shapes`, cả viền map) phủ bằng tảng đá lớn — lớp trong
## tảng to, hàng mép tảng vừa sát mép vật cản (không lòi vào chỗ đi được) — và một dải núi ngoài
## mép map để camera không thấy khoảng trống ngoài map (chỉ hình ảnh).


static func items(layout: MapLayout, cfg: Dictionary, rng: RandomNumberGenerator) -> Array[Array]:
	var m: Dictionary = cfg["mountains"]
	var out: Array[Array] = []
	for shape: MapShape in layout.rock_shapes:
		for p: Vector2 in Scenery3D._fill(shape, m["spacing"], m["inset"], rng):
			out.append(_rock(p, m["scale"], m, rng))
		for p: Vector2 in Scenery3D._rim(shape, m["rim_inset"], m["rim_spacing"], rng):
			out.append(_rock(p, m["rim_scale"], m, rng))
	out.append_array(_outside(layout, m, rng))
	out.append_array(_edge_rim(layout, m, rng))
	return out


## Hàng tảng dày sát ngay ngoài mép map: không còn đường thẳng cỏ / nền tối lộ ra ở mép.
static func _edge_rim(layout: MapLayout, m: Dictionary, rng: RandomNumberGenerator) -> Array[Array]:
	var out: Array[Array] = []
	var r: Rect2 = Rect2(Vector2.ZERO, layout.world_size()).grow(m["edge_offset"])
	var ring: PackedVector2Array = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	for p: Vector2 in Scenery3D._along(ring, m["edge_spacing"], rng):
		out.append(_rock(p, m["edge_scale"], m, rng))
	return out


## Lớp đá thấp, dẹt lấp khe giữa các tảng lớn (D-170): núi nhìn liền, không thấy cỏ lọt giữa.
static func low_items(layout: MapLayout, cfg: Dictionary, rng: RandomNumberGenerator) -> Array[Array]:
	var m: Dictionary = cfg["mountains"]
	var out: Array[Array] = []
	for shape: MapShape in layout.rock_shapes:
		for p: Vector2 in Scenery3D._fill(shape, m["low_spacing"], m["low_inset"], rng):
			out.append([p, rng.randi() % m["low_models"].size(), rng.randf_range(m["low_scale"][0], m["low_scale"][1]), rng.randf() * TAU])
	return out


static func _rock(p: Vector2, scale: Array, m: Dictionary, rng: RandomNumberGenerator) -> Array:
	return [p, rng.randi() % m["models"].size(), rng.randf_range(scale[0], scale[1]), rng.randf() * TAU]


## Dải núi ngoài map: lưới lệch trong vành rộng `outside` quanh khung map.
static func _outside(layout: MapLayout, m: Dictionary, rng: RandomNumberGenerator) -> Array[Array]:
	var out: Array[Array] = []
	var size: Vector2 = layout.world_size()
	var band: float = m["outside"]
	var step: float = m["outside_spacing"]
	var y: float = -band
	while y < size.y + band:
		var x: float = -band
		while x < size.x + band:
			var p: Vector2 = Vector2(x, y) + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4)) * step
			if not Rect2(Vector2.ZERO, size).grow(step * 0.3).has_point(p):
				out.append(_rock(p, m["outside_scale"], m, rng))
			x += step
		y += step * 0.87
	return out
