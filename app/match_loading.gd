class_name MatchLoading
extends RefCounted
## D-260: màn "Đang tải…" lúc vào trận, che ShaderWarmup (vẽ thử mọi mô hình / hiệu ứng để Vulkan biên dịch đường vẽ
## trước). Trong lúc này APP chưa chạy SIM; xong thì gỡ màn che.

var _cover: Control
var _warmup: ShaderWarmup


static func start(view: MatchView3D, hud: Node, focus: Vector2) -> MatchLoading:
	var l: MatchLoading = MatchLoading.new()
	l._warmup = ShaderWarmup.make(view.projectiles, view.to_3d(focus))
	view.add_child(l._warmup)
	var cover: ColorRect = ColorRect.new()
	cover.color = Color(UiStyle.BG, 1.0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.z_index = 100
	var label: Label = Label.new()
	label.text = "Đang tải…"
	label.add_theme_font_override("font", UiStyle.serif(true))
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", UiStyle.GOLD)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cover.add_child(label)
	hud.add_child(cover)
	l._cover = cover
	return l


## Còn đang tải (mỗi khung gọi một lần): true thì APP chưa chạy SIM.
func busy() -> bool:
	if _cover == null:
		return false
	_warmup.step()
	if _warmup.done:
		_cover.queue_free()
		_cover = null
	return true
