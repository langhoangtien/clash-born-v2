class_name UiStyle
extends RefCounted
## Bộ giao diện chung (D-130): phông, màu, khung bảng, thẻ, nút, đồng xu, icon nhỏ — kiểu
## fantasy xanh than + viền vàng như ảnh mẫu (art_inbox/00_style). Mọi màn (shop, chọn tướng,
## bảng trong trận) vẽ bằng các hàm ở đây để đồng bộ. Chỉ vẽ, không giữ trạng thái trận.

const BG: Color = Color(0.035, 0.05, 0.085, 0.97)
const PANEL: Color = Color(0.06, 0.085, 0.135, 0.96)
const CARD: Color = Color(0.085, 0.115, 0.175, 1.0)
const CARD_HI: Color = Color(0.12, 0.155, 0.225, 1.0)
const LINE: Color = Color(0.32, 0.4, 0.55, 0.55)
const GOLD: Color = Color(0.96, 0.78, 0.4)
const GOLD_DEEP: Color = Color(0.62, 0.45, 0.16)
const TEXT: Color = Color(0.94, 0.93, 0.9)
const DIM: Color = Color(0.68, 0.71, 0.78)
const GREEN: Color = Color(0.5, 0.92, 0.55)
const RED_TEXT: Color = Color(1.0, 0.55, 0.45)
const BLUE_BTN: Color = Color(0.12, 0.22, 0.4)
const BLUE_EDGE: Color = Color(0.42, 0.66, 1.0)

static var _serif: Font
static var _serif_bold: Font
static var _sans: Font
static var _sans_bold: Font


## Phông có chân (Lora) cho tiêu đề, tên; `bold` dày hơn.
static func serif(bold: bool = false) -> Font:
	if _serif == null:
		_serif = _variation("res://assets/fonts/Lora-Variable.ttf", 560)
		_serif_bold = _variation("res://assets/fonts/Lora-Variable.ttf", 700)
	return _serif_bold if bold else _serif


## Phông không chân (Carlito) cho số và chữ nhỏ.
static func sans(bold: bool = false) -> Font:
	if _sans == null:
		_sans = _load("res://assets/fonts/Carlito-Regular.ttf")
		_sans_bold = _load("res://assets/fonts/Carlito-Bold.ttf")
	return _sans_bold if bold else _sans


static func _load(path: String) -> Font:
	return load(path) as Font if ResourceLoader.exists(path) else ThemeDB.fallback_font


static func _variation(path: String, weight: int) -> Font:
	var base: Font = _load(path)
	if base == ThemeDB.fallback_font:
		return base
	var v: FontVariation = FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return v


static func box(fill: Color, border: Color, width: int, radius: int, shadow: Color = Color(0, 0, 0, 0), shadow_size: int = 0) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.shadow_color = shadow
	s.shadow_size = shadow_size
	s.anti_aliasing = true
	return s


## Bảng lớn: nền xanh than, viền mảnh, vệt sáng nhẹ phía trên.
static func panel(c: CanvasItem, r: Rect2, radius: int = 14) -> void:
	c.draw_style_box(box(PANEL, LINE, 2, radius, Color(0, 0, 0, 0.45), 18), r)
	var top: Rect2 = Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, minf(80.0, r.size.y * 0.25)))
	c.draw_style_box(box(Color(1, 1, 1, 0.025), Color(0, 0, 0, 0), 0, radius), top)


## Ô vuông bo góc cho icon đồ (D-131): nền xanh than, viền màu `border`.
static func tile(c: CanvasItem, r: Rect2, border: Color, width: int = 2, fill: Color = CARD) -> void:
	c.draw_style_box(box(fill, border, width, maxi(4, int(r.size.x * 0.14))), r)


## Thẻ (món, tướng, ô): đang chọn thì viền vàng sáng và quầng nhẹ.
static func card(c: CanvasItem, r: Rect2, selected: bool = false, dim: bool = false) -> void:
	var fill: Color = CARD_HI if selected else CARD
	if dim:
		fill = fill.darkened(0.15)
	if selected:
		c.draw_style_box(box(fill, GOLD, 3, 10, Color(GOLD, 0.28), 10), r)
	else:
		c.draw_style_box(box(fill, LINE, 1, 10), r)


## Nút: kind = &"gold" (chính), &"blue" (phụ), &"red" (không được), &"ghost" (viền).
static func button(c: CanvasItem, r: Rect2, kind: StringName, text: String, sub: String = "", size: int = 30) -> void:
	var fill: Color = {&"gold": Color(0.55, 0.38, 0.12), &"blue": BLUE_BTN, &"red": Color(0.32, 0.17, 0.15), &"ghost": Color(0.08, 0.1, 0.16)}.get(kind, BLUE_BTN)
	var edge: Color = {&"gold": GOLD, &"blue": BLUE_EDGE, &"red": Color(0.6, 0.35, 0.3), &"ghost": LINE}.get(kind, LINE)
	c.draw_style_box(box(fill, edge, 2, 10, Color(edge, 0.18) if kind == &"gold" else Color(0, 0, 0, 0), 8), r)
	var hi: Rect2 = Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, r.size.y * 0.45))
	c.draw_style_box(box(Color(1, 1, 1, 0.07 if kind == &"gold" else 0.04), Color(0, 0, 0, 0), 0, 8), hi)
	var col: Color = Color(1, 0.95, 0.85) if kind == &"gold" else (RED_TEXT if kind == &"red" else TEXT)
	if sub.is_empty():
		text_center(c, serif(true), r.get_center(), text, size, col)
	else:
		text_center(c, serif(true), r.get_center() - Vector2(0, size * 0.32), text, size, col)
		text_center(c, sans(), r.get_center() + Vector2(0, size * 0.62), sub, int(size * 0.6), Color(col, 0.8))


## Viên nhãn nhỏ ("Bị động", "Không chọn mục tiêu").
static func pill(c: CanvasItem, at: Vector2, text: String, size: int = 17) -> float:
	var f: Font = sans()
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 22.0
	var r: Rect2 = Rect2(at, Vector2(w, size + 12))
	c.draw_style_box(box(Color(0.14, 0.18, 0.26), LINE, 1, int(r.size.y * 0.5)), r)
	c.draw_string(f, at + Vector2(11, size + 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, DIM)
	return w


static func text_center(c: CanvasItem, f: Font, at: Vector2, text: String, size: int, col: Color) -> void:
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string(f, at + Vector2(-w * 0.5, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Đường kẻ mảnh ngăn phần.
static func divider(c: CanvasItem, a: Vector2, b: Vector2) -> void:
	c.draw_line(a, b, LINE, 1.5, true)


## Đồng xu vàng.
static func coin(c: CanvasItem, at: Vector2, r: float) -> void:
	c.draw_circle(at, r, GOLD_DEEP)
	c.draw_circle(at, r * 0.82, GOLD)
	c.draw_arc(at, r * 0.82, 0, TAU, 24, Color(1, 0.95, 0.7, 0.7), 1.5, true)
	text_center(c, serif(true), at + Vector2(0, -1), "$", int(r * 1.15), GOLD_DEEP)


## Icon nhỏ vẽ tay cho giao diện; có ảnh `ui_<name>` thì dùng ảnh.
static func glyph(c: CanvasItem, name: StringName, at: Vector2, s: float, col: Color) -> void:
	var tex: Texture2D = ArtLibrary.texture(StringName("ui_" + String(name)))
	if tex != null:
		c.draw_texture_rect(tex, Rect2(at - Vector2(s, s), Vector2(s, s) * 2.0), false)
		return
	UiGlyphs.draw(c, name, at, s, col)
