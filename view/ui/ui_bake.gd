class_name UiBake
extends RefCounted
## D-290: ảnh dựng sẵn cho hình tròn của giao diện. Trước đây mỗi `UiStyle.orb` là 9 lệnh vẽ (bóng, 5 đĩa, 3 cung)
## không gộp được; HUD trận có ~10 nút tròn. Giờ mỗi bán kính dựng MỘT ảnh 5 ô [bóng | thân | vùng sáng | viền sáng |
## viền tối] (tính từng điểm ảnh, khử răng cưa như bản vẽ cũ); nút vẽ bằng 4 hình chữ nhật cùng ảnh → 1 lệnh vẽ.
## Màu thân không nằm trong ảnh: ô thân trắng nhân màu `fill`, ô vùng sáng là trắng có độ đục = mức lightened của
## 5 đĩa cũ (fill·(1−t) + trắng·t = fill.lightened(t)) → một ảnh dùng cho mọi màu.
## Dựng ảnh tốn ~0,1–0,4 s mỗi bán kính trên PC → các bán kính HUD dùng (RADII) dựng sẵn thành PNG bằng
## `tools/ui/bake_orbs.gd` (BAKED_DIR); bán kính khác mới dựng lúc chạy.

const CELLS: int = 5
enum Cell { SHADOW, BODY, LIGHT, DECO_LIT, DECO_DIM }
## Độ đục [viền vàng đậm, viền vàng mảnh, vệt sáng] khi nút sáng / tối (như UiStyle.orb cũ).
const DECO_ALPHA: Array[Array] = [[1.0, 0.85, 0.16], [0.6, 0.35, 0.06]]

## Bán kính (px) các nút tròn trong game — dựng sẵn PNG. Thêm nút cỡ mới: thêm vào đây rồi chạy lại công cụ.
const RADII: Array[float] = [8.0, 16.0, 17.0, 40.0, 46.0, 56.0, 58.0, 62.0, 105.0]
const BAKED_DIR: String = "res://assets/ui/baked/"

static var _orbs: Dictionary[int, Texture2D] = {}
static var _disc_tex: ImageTexture
static var _ring_tex: ImageTexture
## Cạnh ảnh chấm / vòng (px; có mipmap để thu nhỏ trên minimap). Vòng dày RING_WIDTH × bán kính.
const DOT_SIZE: int = 32
const RING_WIDTH: float = 0.22


## Chấm tròn trắng khử răng cưa (nhân màu khi vẽ) — chấm đơn vị minimap gộp được thành 1 lệnh vẽ.
static func disc_texture() -> ImageTexture:
	if _disc_tex == null:
		_disc_tex = _dot_texture(false)
	return _disc_tex


## Vòng trắng (viền ngoài) — vòng trại / viền tướng trên minimap.
static func ring_texture() -> ImageTexture:
	if _ring_tex == null:
		_ring_tex = _dot_texture(true)
	return _ring_tex


static func _dot_texture(ring: bool) -> ImageTexture:
	var img: Image = Image.create(DOT_SIZE, DOT_SIZE, false, Image.FORMAT_RGBA8)
	var half: float = DOT_SIZE * 0.5
	for y: int in DOT_SIZE:
		for x: int in DOT_SIZE:
			var d: float = Vector2(x + 0.5 - half, y + 0.5 - half).length()
			var a: float = _disc(d, half - 1.0)
			if ring:
				a = _band(d, (half - 1.0) * (1.0 - RING_WIDTH * 0.5), (half - 1.0) * RING_WIDTH)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func baked_path(r: float) -> String:
	return BAKED_DIR + "orb_%d.png" % roundi(r * 2.0)


## Nửa cạnh một ô cho bán kính `r` (đủ chứa bóng lệch xuống 0,07 r và rộng thêm 3 px).
static func half_cell(r: float) -> int:
	return ceili(r * 1.07 + 6.0)


## Ảnh 5 ô của nút tròn bán kính `r` (làm tròn tới nửa px): PNG dựng sẵn nếu có, không thì dựng lần đầu rồi giữ.
static func orb_texture(r: float) -> Texture2D:
	var key: int = roundi(r * 2.0)
	if not _orbs.has(key):
		var path: String = baked_path(key * 0.5)
		if ResourceLoader.exists(path):
			_orbs[key] = load(path) as Texture2D
		else:
			_orbs[key] = ImageTexture.create_from_image(orb_image(key * 0.5))
	return _orbs[key]


## Vẽ nút tròn như UiStyle.orb cũ bằng 4 hình chữ nhật cùng một ảnh.
static func draw_orb(c: CanvasItem, at: Vector2, r: float, fill: Color, lit: bool) -> void:
	var tex: Texture2D = orb_texture(r)
	var s: float = half_cell(r) * 2.0
	var dst: Rect2 = Rect2(at - Vector2(s, s) * 0.5, Vector2(s, s))
	var base: Color = fill if lit else fill.darkened(0.45)
	c.draw_texture_rect_region(tex, dst, _cell(Cell.SHADOW, s))
	c.draw_texture_rect_region(tex, dst, _cell(Cell.BODY, s), base)
	c.draw_texture_rect_region(tex, dst, _cell(Cell.LIGHT, s))
	c.draw_texture_rect_region(tex, dst, _cell(Cell.DECO_LIT if lit else Cell.DECO_DIM, s))


static func _cell(cell: Cell, s: float) -> Rect2:
	return Rect2(Vector2(cell * s, 0), Vector2(s, s))


## Độ phủ đĩa bán kính `radius` tại khoảng cách `d` (khử răng cưa 1 px).
static func _disc(d: float, radius: float) -> float:
	return clampf(radius - d + 0.5, 0.0, 1.0)


## Độ phủ vành tâm `mid`, dày `w`.
static func _band(d: float, mid: float, w: float) -> float:
	return clampf(minf(d - (mid - w * 0.5), (mid + w * 0.5) - d) + 0.5, 0.0, 1.0)


static func orb_image(r: float) -> Image:
	var half: int = half_cell(r)
	var s: int = half * 2
	var w: int = s * CELLS
	var data: PackedByteArray = PackedByteArray()
	data.resize(w * s * 4)
	for y: int in s:
		for x: int in s:
			var dx: float = x + 0.5 - half
			var dy: float = y + 0.5 - half
			var d: float = sqrt(dx * dx + dy * dy)
			var row: int = (y * w + x) * 4
			_put(data, row, Cell.SHADOW, s, Color(0, 0, 0, 0.32 * _disc(Vector2(dx, dy - r * 0.07).length(), r + 3.0)))
			_put(data, row, Cell.BODY, s, Color(1, 1, 1, _disc(d, r)))
			var t: float = 0.0
			for k: int in range(1, 5):
				t += 0.06 * _disc(d, r * (1.0 - k * 0.14))
			_put(data, row, Cell.LIGHT, s, Color(1, 1, 1, t))
			for lit: int in 2:
				_put(data, row, Cell.DECO_LIT + lit, s, _deco(r, d, dx, dy, DECO_ALPHA[lit]))
	return Image.create_from_data(w, s, false, Image.FORMAT_RGBA8, data)


## Viền vàng đậm (r − 2, dày 4), viền vàng mảnh (r − 4,5, dày 1,5), vệt sáng cung trên (0,72 r, dày 0,13 r).
static func _deco(r: float, d: float, dx: float, dy: float, alpha: Array) -> Color:
	var out: Color = Color(UiStyle.GOLD_DEEP, alpha[0] * _band(d, r - 2.0, 4.0))
	out = _over(Color(UiStyle.GOLD, alpha[1] * _band(d, r - 4.5, 1.5)), out)
	var glow: float = _band(d, r * 0.72, r * 0.13)
	if glow > 0.0:
		var ang: float = fposmod(atan2(dy, dx), TAU)
		glow *= clampf((ang - PI * 1.18) * d + 0.5, 0.0, 1.0) * clampf((PI * 1.82 - ang) * d + 0.5, 0.0, 1.0)
		out = _over(Color(1, 1, 1, alpha[2] * glow), out)
	return out


## `src` đè lên `dst` (độ đục thường, không nhân trước).
static func _over(src: Color, dst: Color) -> Color:
	var a: float = src.a + dst.a * (1.0 - src.a)
	if a <= 0.0:
		return Color(0, 0, 0, 0)
	var rgb: Color = (src * src.a + dst * dst.a * (1.0 - src.a)) / a
	return Color(rgb.r, rgb.g, rgb.b, a)


static func _put(data: PackedByteArray, row: int, cell: int, s: int, col: Color) -> void:
	var i: int = row + cell * s * 4
	data[i] = roundi(col.r * 255.0)
	data[i + 1] = roundi(col.g * 255.0)
	data[i + 2] = roundi(col.b * 255.0)
	data[i + 3] = roundi(col.a * 255.0)
