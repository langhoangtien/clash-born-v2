extends RefCounted
## Vẽ lớp ký hiệu map dev (M5.6, D-77): lưới ô cờ + tên ô ở góc mỗi ô, tên các thứ trên map
## (MapLabels). Dùng qua preload, không class_name.

const GRID_LINE: Color = Color(1, 1, 1, 0.22)
const CELL_TEXT: Color = Color(1, 1, 1, 0.45)
const COLORS: Dictionary = {
	MapLabels.Kind.TOWER: Color(1.0, 1.0, 1.0),
	MapLabels.Kind.CAMP: Color(1.0, 0.85, 0.3),
	MapLabels.Kind.BUSH: Color(0.7, 1.0, 0.45),
	MapLabels.Kind.FOREST: Color(0.55, 0.9, 0.7),
	MapLabels.Kind.LANDMARK: Color(1.0, 0.55, 0.9),
	MapLabels.Kind.SHOP: Color(1.0, 0.8, 0.2),
}
## Cỡ chữ theo đơn vị map (lớp nằm trong thế giới, phóng to thu nhỏ theo camera).
const TEXT_SIZE: int = 72
const CELL_SIZE_TEXT: int = 44


static func paint(ci: CanvasItem, layout: MapLayout) -> void:
	var font: Font = ThemeDB.fallback_font
	var s: float = MapLabels.cell_size(layout)
	var size: Vector2 = layout.world_size()
	for i: int in range(MapLabels.GRID + 1):
		ci.draw_line(Vector2(i * s, 0), Vector2(i * s, size.y), GRID_LINE, 4.0)
		ci.draw_line(Vector2(0, i * s), Vector2(size.x, i * s), GRID_LINE, 4.0)
	for row: int in range(MapLabels.GRID):
		for col: int in range(MapLabels.GRID):
			var name: String = MapLabels.COLUMNS[col] + str(row + 1)
			ci.draw_string(font, Vector2(col * s + 14, row * s + CELL_SIZE_TEXT + 6), name, HORIZONTAL_ALIGNMENT_LEFT, -1, CELL_SIZE_TEXT, CELL_TEXT)
	var placed: Array[Vector2] = []
	for mark: MapLabels.Mark in MapLabels.build(layout):
		var at: Vector2 = mark.position
		while placed.any(func(q: Vector2) -> bool: return absf(q.x - at.x) < 140.0 and absf(q.y - at.y) < TEXT_SIZE):
			at.y += TEXT_SIZE  # nhãn đè nhau thì dời xuống
		placed.append(at)
		_text(ci, font, at, mark.text, COLORS[mark.kind])


static func _text(ci: CanvasItem, font: Font, center: Vector2, text: String, color: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	var at: Vector2 = center + Vector2(-w * 0.5, TEXT_SIZE * 0.35)
	ci.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, 14, Color(0, 0, 0, 0.85))
	ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, color)
