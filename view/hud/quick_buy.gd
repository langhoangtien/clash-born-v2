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
## D-263: bước vẽ lại viền nhấp nháy (ms).
const PULSE_STEP_MS: int = 50
var _phase: int = -1


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
	var phase: int = Time.get_ticks_msec() / PULSE_STEP_MS
	if item != null and phase != _phase:
		_phase = phase
		queue_redraw()  # viền nhấp nháy; D-263: 20 lần / giây là đủ mượt


func _draw() -> void:
	var t: int = FrameProfile.now()  # D-263: đo thời gian vẽ từng bảng HUD
	_paint()
	FrameProfile.shared.hud(&"hud_quick", t)


func _paint() -> void:
	if item == null:
		return
	var pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 220.0)
	var half: float = RADIUS + 4.0  # ô vuông bo góc (D-131)
	UiStyle.soft_frame(self, Rect2(CENTER - Vector2(half, half), Vector2(half, half) * 2.0), int(half * 0.35), Color(UiStyle.CARD, 0.92))  # D-222
	draw_style_box(UiStyle.box(Color(0, 0, 0, 0), Color(1, 0.85, 0.3, pulse), 3, int(half * 0.35)), Rect2(CENTER - Vector2(half, half), Vector2(half, half) * 2.0).grow(2))
	var tex: Texture2D = ArtLibrary.texture(item.art_id)
	if tex != null:
		draw_texture_rect(tex, Rect2(CENTER - Vector2(RADIUS, RADIUS) * 0.9, Vector2(RADIUS, RADIUS) * 1.8), false)
	var font: Font = UiStyle.sans(true)
	var text: String = str(price)  # D-222: đồng xu + giá trong viên dưới ô
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var pill: Rect2 = Rect2(CENTER + Vector2(-(w + 34) * 0.5, RADIUS + 10.0), Vector2(w + 34, 30))
	UiStyle.soft_frame(self, pill, 15, Color(0.04, 0.06, 0.1, 0.9))
	UiStyle.coin(self, pill.position + Vector2(15, 15), 9.0)
	draw_string(font, pill.position + Vector2(28, 23), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.88, 0.45))
