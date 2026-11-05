class_name FrameProbe
extends Node
## D-261: mốc thời gian mỗi khung cho FrameProfile. Nút này chạy `_process` TRƯỚC mọi nút (gộp khung trước,
## ghi bộ đếm); nút con `_Tail` chạy SAU mọi nút. Từ cuối `_process` tới lúc RenderingServer bắt đầu vẽ là
## phần vẽ 2D (`_draw` của HUD, cập nhật canvas); từ lúc bắt đầu tới xong vẽ là phần dựng khung 3D trên CPU.

const FIRST: int = -100000
const LAST: int = 100000

var profile: FrameProfile = FrameProfile.shared
var world: World
var view_3d: MatchView3D
var _start: int = -1
var _end: int = -1
var _pre: int = -1


class _Tail:
	extends Node
	var probe: FrameProbe

	func _process(_delta: float) -> void:
		probe.mark_end()


## Gắn dưới `parent` (màn trận).
static func attach(parent: Node, w: World, v: MatchView3D) -> FrameProbe:
	var p: FrameProbe = FrameProbe.new()
	p.name = "FrameProbe"
	p.world = w
	p.view_3d = v
	parent.add_child(p)
	return p


func _ready() -> void:
	process_priority = FIRST
	var tail: _Tail = _Tail.new()
	tail.probe = self
	tail.process_priority = LAST
	add_child(tail)
	RenderingServer.frame_pre_draw.connect(_pre_draw)
	RenderingServer.frame_post_draw.connect(_post_draw)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(_pre_draw)
	RenderingServer.frame_post_draw.disconnect(_post_draw)


func _process(_delta: float) -> void:
	profile.next_frame()
	_start = FrameProfile.now()
	_count()


func mark_end() -> void:
	if _start >= 0:
		_end = profile.lap(&"process", _start)


func _pre_draw() -> void:
	_pre = FrameProfile.now()
	if _end >= 0:
		profile.add(&"draw2d", _end, _pre)


func _post_draw() -> void:
	if _pre >= 0:
		profile.add(&"render", _pre)
	var rid: RID = get_viewport().get_viewport_rid()
	profile.add(&"gpu", 0, int(RenderingServer.viewport_get_measured_render_time_gpu(rid) * 1000.0))


func _count() -> void:
	if world != null:
		profile.set_count(&"entities", world.entities.size())
		profile.set_count(&"tick", world.tick)
	if view_3d != null:
		view_3d.count_into(profile)
	profile.set_count(&"nodes", int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	profile.set_count(&"orphans", int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))
	profile.set_count(&"objects", int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	profile.set_count(&"draw_calls", int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	profile.set_count(&"triangles_k", int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0))
