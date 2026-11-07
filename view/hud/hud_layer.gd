class_name HudLayer
extends Control
## D-290: một lớp vẽ của HUD có cổng vẽ lại riêng (RedrawGate) — phần đổi thường (số máu ~6 lần / giây) không
## kéo theo phần ít đổi (băng rôn tỷ số, chân dung). Lớp chỉ gọi `paint(canvas)` của chủ; không nhận chạm.

## func(c: CanvasItem) -> void — vẽ lên lớp này.
var paint: Callable
## func() -> Array — mọi giá trị đúng như sẽ hiện; đổi thì vẽ lại.
var key: Callable
var _gate: RedrawGate = RedrawGate.new()


static func make(parent: Control, layer_name: String, paint_fn: Callable, key_fn: Callable) -> HudLayer:
	var l: HudLayer = HudLayer.new()
	l.name = layer_name
	l.paint = paint_fn
	l.key = key_fn
	parent.add_child(l)
	return l


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	if _gate.changed(key.call()):
		queue_redraw()


func _draw() -> void:
	var t: int = FrameProfile.now()  # D-263: đo thời gian vẽ từng bảng HUD
	paint.call(self)
	FrameProfile.shared.hud(&"hud_top", t)
