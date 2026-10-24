class_name MapBaker
extends Node2D
## Nướng các lớp tĩnh của bản đồ (nền, vật cản, bụi, shop) thành lưới ô ảnh một lần lúc vào trận
## (D-147). Vẽ hàng nghìn đa giác / nét mỗi khung là phần nặng nhất trên máy yếu; ô ảnh chỉ tốn
## một lần vẽ mỗi ô và ô ngoài màn hình tự bị bỏ qua. Trong lúc nướng, các lớp gốc vẫn hiện.

signal baked

## Độ phân giải ô so với thế giới (0.5 = 1 điểm ảnh cho 2 px thế giới; khớp lớp đất bản 3D).
const SCALE: float = 0.5
## Cạnh một ô (px thế giới).
const TILE: float = 2112.0

var tiles: Array[Sprite2D] = []


## Có nên nướng không: cần trình vẽ thật (bỏ qua khi chạy headless / test).
static func can_bake() -> bool:
	return DisplayServer.get_name() != "headless"


## Nướng `layers` (các CanvasItem đang vẽ) trên bản đồ cỡ `size`, rồi ẩn chúng.
func bake(layers: Array[CanvasItem], painters: Array[Callable], size: Vector2) -> void:
	var px: int = int(TILE * SCALE)
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var holder: Node2D = Node2D.new()
	holder.scale = Vector2.ONE * SCALE
	vp.add_child(holder)
	for p: Callable in painters:
		var layer: _Painter = _Painter.new()
		layer.painter = p
		holder.add_child(layer)
	var cols: int = ceili(size.x / TILE)
	var rows: int = ceili(size.y / TILE)
	for row: int in rows:
		for col: int in cols:
			var origin: Vector2 = Vector2(col, row) * TILE
			holder.position = -origin * SCALE
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			_add_tile(ImageTexture.create_from_image(vp.get_texture().get_image()), origin)
	vp.queue_free()
	for l: CanvasItem in layers:
		l.visible = false
	baked.emit()


func _add_tile(tex: Texture2D, origin: Vector2) -> void:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = origin
	s.scale = Vector2.ONE / SCALE
	add_child(s)
	tiles.append(s)


class _Painter extends Node2D:
	var painter: Callable

	func _draw() -> void:
		painter.call(self)
