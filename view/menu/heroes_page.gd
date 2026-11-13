class_name HeroesPage
extends Control
## D-413: trang Tướng — trái: danh sách tướng, lọc theo thuộc tính chính; giữa: khung mô hình 3D lớn (HeroModelView,
## D-412: vuốt xoay, nút hoạt ảnh); phải: đầu khung + thẻ Chiêu / Chỉ số / Talent (HeroDetail) và nút "Thử tướng" (vào
## trận thử 1v1 với tướng đó — APP mở). Mô hình chỉ dựng khi trang đang hiện; rời trang thì gỡ.

signal try_pressed(hero_id: StringName)

const FILTERS: Array[String] = ["Tất cả", "Sức mạnh", "Nhanh", "Trí tuệ"]
const LIST_W: float = 420.0
const RIGHT_MIN: float = 760.0  ## cột chi tiết: tối thiểu (1920) — rộng theo màn (20:9)
const PAD: float = 32.0
const CELL: Vector2 = Vector2(118, 150)
const COLUMNS: int = 3
const TABS: Array[HeroDetail.Tab] = [HeroDetail.Tab.SKILLS, HeroDetail.Tab.STATS, HeroDetail.Tab.TALENTS]

var previews: Array[HeroPreview] = []
var selected: int = 0
## 0 = tất cả; 1..3 = HeroDef.primary_attribute.
var filter: int = 0
var tab: HeroDetail.Tab = HeroDetail.Tab.SKILLS
var model_view: HeroModelView


func setup(list: Array[HeroPreview]) -> void:
	previews = list
	mouse_filter = Control.MOUSE_FILTER_STOP
	model_view = HeroModelView.new()
	model_view.name = "HeroModelView"
	add_child(model_view)
	visibility_changed.connect(_sync_model)
	resized.connect(_sync_model)


## Chỉ số các tướng đang hiện theo bộ lọc.
func shown() -> Array[int]:
	var out: Array[int] = []
	for i: int in previews.size():
		if filter == 0 or previews[i].def.primary_attribute == filter:
			out.append(i)
	return out


func filter_rect(i: int) -> Rect2:
	return Rect2(Vector2(PAD + i * 96, 76), Vector2(90, 48))


func cell_rect(k: int) -> Rect2:
	return Rect2(Vector2(PAD + 6 + (k % COLUMNS) * (CELL.x + 10), 140 + (k / COLUMNS) * (CELL.y + 10)), CELL)


func right_w() -> float:
	return maxf(RIGHT_MIN, size.x * 0.36)


func model_rect() -> Rect2:
	var x: float = PAD + LIST_W + 24
	return Rect2(Vector2(x, 24), Vector2(size.x - x - right_w() - PAD - 24, size.y - 24 - PAD))


func right_rect() -> Rect2:
	return Rect2(Vector2(size.x - right_w() - PAD, 24), Vector2(right_w(), size.y - 24 - PAD))


func tab_rect(i: int) -> Rect2:
	var r: Rect2 = right_rect()
	return Rect2(r.position + Vector2(20 + i * 210, 176), Vector2(200, 54))


func tab_area() -> Rect2:
	var r: Rect2 = right_rect()
	return Rect2(r.position + Vector2(20, 250), Vector2(r.size.x - 40, r.size.y - 250 - 130))


func try_rect() -> Rect2:
	var r: Rect2 = right_rect()
	return Rect2(Vector2(r.end.x - 360, r.end.y - 112), Vector2(340, 92))


func press_at(at: Vector2) -> void:
	for i: int in FILTERS.size():
		if filter_rect(i).has_point(at):
			filter = i
			var list: Array[int] = shown()
			if not list.is_empty() and not list.has(selected):
				selected = list[0]
	var list: Array[int] = shown()
	for k: int in list.size():
		if cell_rect(k).has_point(at):
			selected = list[k]
	for i: int in TABS.size():
		if tab_rect(i).has_point(at):
			tab = TABS[i]
	if try_rect().has_point(at) and not previews.is_empty():
		try_pressed.emit(previews[selected].def.id)
	_sync_model()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var at: Vector2 = Taps.press_position(event)  # D-102
	if at.is_finite():
		press_at(at)
		accept_event()


## Trang đang hiện → khung 3D hiện tướng đang chọn; ẩn → gỡ mô hình (D-412: một mô hình, giải phóng khi rời).
func _sync_model() -> void:
	if model_view == null:
		return
	var r: Rect2 = model_rect()
	model_view.position = r.position
	model_view.size = r.size
	if not is_visible_in_tree() or previews.is_empty():
		model_view.clear()
		return
	model_view.show_hero(previews[selected])


func _draw() -> void:
	UiStyle.panel(self, Rect2(Vector2(PAD - 12, 24), Vector2(LIST_W, size.y - 24 - PAD)))
	draw_string(UiStyle.serif(true), Vector2(PAD, 62), "Danh sách tướng", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UiStyle.GOLD)
	for i: int in FILTERS.size():
		UiStyle.button(self, filter_rect(i), &"gold" if i == filter else &"ghost", FILTERS[i], "", 17)
	var list: Array[int] = shown()
	for k: int in list.size():
		_cell(cell_rect(k), previews[list[k]], list[k] == selected)
	if previews.is_empty():
		return
	var p: HeroPreview = previews[selected]
	UiStyle.panel(self, right_rect())
	HeroDetail.draw_header(self, p, right_rect().position + Vector2(20, 18))
	for i: int in TABS.size():
		UiStyle.tab(self, tab_rect(i), HeroDetail.TAB_NAMES[TABS[i]], TABS[i] == tab)
	HeroDetail.draw_tab(self, p, tab, tab_area())
	draw_string(UiStyle.sans(), Vector2(right_rect().position.x + 24, try_rect().get_center().y + 8), "Trận thử 1v1 với bot",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiStyle.DIM)
	UiStyle.button(self, try_rect(), &"gold", "THỬ TƯỚNG", "", 34)


func _cell(r: Rect2, p: HeroPreview, on: bool) -> void:
	UiStyle.card(self, r, on)
	HeroDetail.portrait(self, p, Rect2(r.position + Vector2(10, 8), Vector2(r.size.x - 20, r.size.x - 20)), on)
	UiStyle.text_center(self, UiStyle.serif(true), Vector2(r.get_center().x, r.end.y - 14), p.def.display_name.get_slice(" · ", 0), 17, UiStyle.TEXT)
