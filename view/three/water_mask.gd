class_name WaterMask
extends SubViewport
## D-160: mặt nạ sông nước (trắng = nước) cho mặt đất 3D gợn sóng: vẽ các water_shapes (thu vào trong
## INSET px để bờ không gợn) một lần vào ảnh nhỏ, rồi gọi `done` với ảnh đó và tự bỏ.

## Điểm ảnh mỗi px thế giới; thu mép vào trong.
const SCALE: float = 1.0 / 16.0
const INSET: float = 40.0

signal done(texture: Texture2D)

var _layout: MapLayout


static func bake(parent: Node, layout: MapLayout) -> WaterMask:
	var m: WaterMask = WaterMask.new()
	m._layout = layout
	m.size = Vector2i((layout.world_size() * SCALE).ceil())
	m.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter: _Painter = _Painter.new()
	painter.layout = layout
	painter.scale = Vector2.ONE * SCALE
	m.add_child(painter)
	parent.add_child(m)
	m._finish.call_deferred()
	return m


func _finish() -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_texture().get_image()
	img.generate_mipmaps()
	done.emit(ImageTexture.create_from_image(img))
	queue_free()


class _Painter extends Node2D:
	var layout: MapLayout

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, layout.world_size()), Color.BLACK)
		for shape: MapShape in layout.water_shapes:
			for inner: PackedVector2Array in Geometry2D.offset_polygon(shape.outer, -WaterMask.INSET, Geometry2D.JOIN_ROUND):
				draw_colored_polygon(inner, Color.WHITE)
