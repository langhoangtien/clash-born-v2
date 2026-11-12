class_name BotControl
extends RefCounted
## NET-17 / NET-18 (D-390, M9.7): đổi quyền điều khiển hero giữa người và bot theo lệnh SET_CONTROL (chỉ máy chủ phòng
## phát). CommandSystem gọi ở pha COMMAND; không đọc gì ngoài World + lệnh (D-30). Không gỡ trạng thái / hiệu ứng, không
## hủy kênh về thành.


static func apply(world: World, e: Entity, bot: bool) -> void:
	if bot:
		_to_bot(world, e)
	else:
		_to_human(e)


## NET-17: gắn bot Thường (R1), đường theo ô; hủy lệnh đi đang giữ của người để bot ra lệnh mới. Đã là bot → không làm gì.
static func _to_bot(world: World, e: Entity) -> void:
	if e.bot != null:
		return
	MatchSetup.add_bot(world, e, BotState.Difficulty.NORMAL).lane = MatchSetup.lane_for(world, e)
	if e.order.type == Order.Type.MOVE or e.order.type == Order.Type.DIRECT:
		e.order = Order.idle()
	if e.queued_order != null and (e.queued_order.type == Order.Type.MOVE or e.queued_order.type == Order.Type.DIRECT):
		e.queued_order = null


## NET-18: gỡ bot, hero dừng (như STOP) chờ lệnh người. Đã là người → không làm gì. BotController ở lại World.
static func _to_human(e: Entity) -> void:
	if e.bot == null:
		return
	e.bot = null
	if e.cast != null or e.dash != null:
		e.queued_order = Order.idle()  # D-59, ABL-08: đang tung chiêu / lướt thì dừng sau khi xong
	else:
		e.order = Order.idle()
