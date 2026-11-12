class_name ReplayScreen
extends ColorRect
## NET-22 (D-411): màn che lúc tua vào lại — ẩn và dừng cập nhật cảnh trận (3D, 2D, HUD) để gần hết thời gian khung cho
## SIM; chỉ còn nền, chữ "Đang vào lại trận… N%" (OnlineMatch) và nút Cài đặt (thoát trận giữa lúc tua). Tua xong → trả
## mọi nút về đúng trạng thái hiện / chạy trước đó, rồi đồng bộ hình theo World hiện tại (không nội suy từ vị trí cũ, đơn
## vị chết lúc tua không thành xác).

var units_view: UnitsView
var view_3d: MatchView3D
var hero: Entity
var _nodes: Array[Node] = []
var _keep: Array[Node] = []
var _saved: Dictionary[Node, Array] = {}  ## nút → [visible, process_mode] trước khi che


## Màn che trên lớp HUD `hud` (dưới mọi nút); `nodes` = các nút cảnh trận cần che, `keep` = nút trong HUD vẫn hiện.
static func make(hud: Node, nodes: Array[Node], keep: Array[Node], units: UnitsView, view: MatchView3D, h: Entity) -> ReplayScreen:
	var r: ReplayScreen = ReplayScreen.new()
	r.name = "ReplayScreen"
	r.color = UiStyle.BG
	r.mouse_filter = Control.MOUSE_FILTER_STOP  # không bấm nhầm nút trận bên dưới khi đang tua
	r.visible = false
	r._nodes = nodes + hud.get_children()
	r._keep = keep
	r.units_view = units
	r.view_3d = view
	r.hero = h
	hud.add_child(r)
	hud.move_child(r, 0)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r


## Mỗi khung: `on` = đang tua → che, trả true (màn trận bỏ cập nhật hình khung này); vừa tua xong → bỏ che + đồng bộ hình.
func hold(on: bool) -> bool:
	if on:
		cover()
		return true
	if visible:
		lift()
		resync()
	return false


func cover() -> void:
	if visible:
		return
	visible = true
	for n: Node in _nodes:
		if n == self or not is_instance_valid(n) or _keep.has(n) or _saved.has(n):
			continue
		_saved[n] = [n.get("visible"), n.process_mode]
		n.set("visible", false)
		n.process_mode = Node.PROCESS_MODE_DISABLED


## Trả từng nút về như trước khi che.
func lift() -> void:
	visible = false
	for n: Node in _saved:
		if is_instance_valid(n):
			n.set("visible", _saved[n][0])
			n.process_mode = _saved[n][1]
	_saved.clear()


## Hình theo World hiện tại: vị trí không nội suy; hình đơn vị đã bị gỡ lúc tua bỏ thẳng (hình đang ẩn → không thành xác).
func resync() -> void:
	units_view.capture_previous()
	if view_3d != null:
		view_3d.set_part(&"actors", false)
		view_3d.update(units_view.display_position(hero))
		view_3d.set_part(&"actors", true)
