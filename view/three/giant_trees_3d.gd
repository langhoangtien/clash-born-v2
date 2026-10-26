class_name GiantTrees3D
extends RefCounted
## Cây cổ thụ khổng lồ làm điểm nhấn (D-170): rải thưa trong khối rừng và núi đá đủ rộng, và ngoài mép map — chỉ ở chỗ
## lùi vào trong mép một khoảng bằng bán kính tán, nên tán không trùm ra chỗ đi được. Cây thường
## trong bán kính tán cổ thụ bị bỏ (một cây lớn thay cả cụm, nhẹ hơn).
## Phần tử: [vị trí, loại (chỉ số trong cfg.giants.models), cỡ, góc]; cố định theo map.

const SEED: int = 11


static func items(layout: MapLayout) -> Array[Array]:
	var cfg: Dictionary = ModelLibrary.scenery().get("giants", {})
	var out: Array[Array] = []
	if cfg.is_empty():
		return out
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	for shape: MapShape in layout.forest_shapes + layout.rock_shapes:
		for kind: int in cfg["models"].size():  # mỗi mẫu lùi vào mép theo cỡ tán của nó
			for p: Vector2 in _spots(shape, cfg["inset"][kind], cfg["spacing"], rng):
				if rng.randf() < cfg["chance"] and not covers(out, p, cfg["spacing"] * 0.7):
					out.append(_giant(p, cfg, rng, kind))
	out.append_array(_outside(layout, cfg, rng))
	return out


## Rừng cổ thụ ngoài mép map (chỉ hình ảnh).
static func _outside(layout: MapLayout, cfg: Dictionary, rng: RandomNumberGenerator) -> Array[Array]:
	var out: Array[Array] = []
	var size: Vector2 = layout.world_size()
	var band: float = cfg["outside"]
	var y: float = -band
	while y < size.y + band:
		var x: float = -band
		while x < size.x + band:
			var p: Vector2 = Vector2(x, y) + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)) * cfg["outside_spacing"]
			if not Rect2(Vector2.ZERO, size).grow(250.0).has_point(p) and rng.randf() < cfg["chance"]:
				out.append(_giant(p, cfg, rng))
			x += cfg["outside_spacing"]
		y += cfg["outside_spacing"]
	return out


## Chỗ đặt được: lưới thưa trong phần lùi vào `inset`, cộng tâm mỗi phần lùi vào đủ rộng.
static func _spots(shape: MapShape, inset: float, spacing: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out: PackedVector2Array = Scenery3D._fill(shape, spacing, inset, rng)
	for inner: PackedVector2Array in Geometry2D.offset_polygon(shape.outer, -inset):
		if not Geometry2D.is_polygon_clockwise(inner) == Geometry2D.is_polygon_clockwise(shape.outer):
			continue
		var c: Vector2 = Vector2.ZERO
		for q: Vector2 in inner:
			c += q
		c /= inner.size()
		if Geometry2D.is_point_in_polygon(c, inner):
			out.append(c)
	return out


static func _giant(p: Vector2, cfg: Dictionary, rng: RandomNumberGenerator, kind: int = -1) -> Array:
	if kind < 0:
		kind = rng.randi() % cfg["models"].size()
	return [p, kind, rng.randf_range(cfg["scale"][kind][0], cfg["scale"][kind][1]), rng.randf() * TAU]


## Có cổ thụ nào trùm lên điểm `p` không (bán kính `clear` px).
static func covers(giants: Array[Array], p: Vector2, clear: float) -> bool:
	for g: Array in giants:
		if g[0].distance_to(p) < clear:
			return true
	return false
