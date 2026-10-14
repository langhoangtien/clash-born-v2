class_name EffectInstance
extends RefCounted
## Một hiệu ứng đang có trên đơn vị (EFF). Giá trị có tên chụp lúc áp (EFF-09).

## Số thứ tự toàn trận (World cấp), dùng làm nguồn modifier và thứ tự (khiên cũ trước).
var serial: int
var def: EffectDef
var owner_id: int
## Đơn vị áp hiệu ứng (-1 nếu không có); được tính là kẻ gây sát thương periodic.
var source_id: int = -1
var values: Dictionary = {}
var stacks: int = 1
var start_tick: int
## Tick hết hạn (EffectSystem gỡ ở pha EFFECT của tick đó); -1 = vĩnh viễn.
var end_tick: int = -1
## Khiên còn lại (EFF-06); -1 = không phải khiên.
var absorb_left: float = -1.0
var period_ticks: int = 0
var next_period_tick: int = -1
## Ô đồ của nguồn (STAT-05, D-55), 0 = không phải đồ.
var item_slot: int = 0
