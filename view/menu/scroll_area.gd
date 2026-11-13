class_name ScrollArea
extends RefCounted
## D-413: vùng cuộn của các lưới vẽ tay ở menu (lưới tướng, hàng đối thủ…) — dọc hoặc ngang, cuộn bằng vuốt / lăn chuột,
## giới hạn theo kích thước nội dung. Trang giữ `rect` (khung nhìn) và `content` (độ dài nội dung theo chiều cuộn).

const WHEEL_STEP: float = 120.0

var rect: Rect2 = Rect2()
var content: float = 0.0
var vertical: bool = true
var offset: float = 0.0


static func make(is_vertical: bool) -> ScrollArea:
	var s: ScrollArea = ScrollArea.new()
	s.vertical = is_vertical
	return s


func max_offset() -> float:
	return maxf(0.0, content - (rect.size.y if vertical else rect.size.x))


func scroll_by(px: float) -> void:
	offset = clampf(offset + px, 0.0, max_offset())


## Dịch vị trí nội dung theo độ cuộn.
func shift(at: Vector2) -> Vector2:
	return at - (Vector2(0, offset) if vertical else Vector2(offset, 0))


## Ô `r` (đã dịch) nằm trọn trong khung nhìn → vẽ / bấm được.
func shows(r: Rect2) -> bool:
	return rect.encloses(r)


## Vuốt / lăn trong khung → cuộn; true nếu đã dùng sự kiện.
func handle(event: InputEvent) -> bool:
	if event is InputEventScreenDrag and rect.has_point((event as InputEventScreenDrag).position):
		var d: Vector2 = (event as InputEventScreenDrag).relative
		scroll_by(-(d.y if vertical else d.x))
		return true
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and rect.has_point((event as InputEventMouseButton).position):
		var b: MouseButton = (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP or b == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_by(-WHEEL_STEP if b == MOUSE_BUTTON_WHEEL_UP else WHEEL_STEP)
			return true
	return false


## Thanh cuộn mảnh ở mép khung khi nội dung dài hơn khung.
func draw_bar(c: CanvasItem) -> void:
	if max_offset() <= 0.0:
		return
	var span: float = rect.size.y if vertical else rect.size.x
	var part: float = maxf(40.0, span * span / content)
	var at: float = (span - part) * offset / max_offset()
	var r: Rect2 = Rect2(Vector2(rect.end.x + 4, rect.position.y + at), Vector2(6, part)) if vertical \
		else Rect2(Vector2(rect.position.x + at, rect.end.y + 6), Vector2(part, 6))
	c.draw_style_box(UiStyle.box(Color(UiStyle.GOLD, 0.6), Color(0, 0, 0, 0), 0, 3), r)
