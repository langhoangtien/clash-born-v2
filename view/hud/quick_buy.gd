class_name QuickBuy
extends Control
## Nút mua nhanh kiểu Liên Quân (SHOP-10, D-117): bên trái màn hình, trên vùng joystick. Hiện
## món nên mua lúc này theo thứ tự lên đồ (BuildPlan) khi đủ vàng; chạm = mua. Không đủ vàng
## mua món nào thì ẩn. Chỉ vẽ và báo chạm; APP đặt `item` và gửi lệnh mua.

signal pressed(id: StringName)

const CENTER: Vector2 = Vector2(110, 450)
const RADIUS: float = 52.0

## Món đang mời mua (null = ẩn) và giá phải trả.
var item: ItemDef
var price: int = 0


func show_item(d: ItemDef, cost: int) -> void:
	if d != item or cost != price:
		item = d
		price = cost
		queue_redraw()


func _has_point(point: Vector2) -> bool:
	return item != null and point.distance_to(CENTER) <= RADIUS + 8.0


func _gui_input(event: InputEvent) -> void:
	if item != null and Taps.press_position(event).is_finite():  # D-102
		pressed.emit(item.id)
		accept_event()


func _process(_delta: float) -> void:
	if item != null:
		queue_redraw()  # viền nhấp nháy


func _draw() -> void:
	if item == null:
		return
	var pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 220.0)
	draw_circle(CENTER, RADIUS + 6.0, Color(0.05, 0.06, 0.09, 0.85))
	var tex: Texture2D = ArtLibrary.texture(item.art_id)
	if tex != null:
		draw_texture_rect(tex, Rect2(CENTER - Vector2(RADIUS, RADIUS), Vector2(RADIUS, RADIUS) * 2.0), false)
	else:
		draw_circle(CENTER, RADIUS, Color(0.4, 0.35, 0.2))
	draw_arc(CENTER, RADIUS + 5.0, 0, TAU, 48, Color(1, 0.85, 0.3, pulse), 4.0, true)
	var font: Font = ThemeDB.fallback_font
	var text: String = "Mua %d" % price
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var at: Vector2 = CENTER + Vector2(-w * 0.5, RADIUS + 30.0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0, 0.85))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.85, 0.3))
