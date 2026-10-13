class_name Entity
extends RefCounted
## Một đơn vị trên sân (ARCHITECTURE 3.1). Chỉ có các trường mà hệ thống hiện có cần;
## thêm trường khi hệ thống dùng nó được làm (không làm trước).

enum Kind { HERO, LANE_CREEP, NEUTRAL, TOWER, CORE }

## Do World cấp, tăng dần, không dùng lại; quyết định thứ tự xử lý.
var id: int = -1
var team: int = 0  # 0 Blue, 1 Red, 2 trung lập
var kind: Kind = Kind.HERO
var position: Vector2 = Vector2.ZERO
var radius: float = 0.0
var stats: StatBlock
var health: float = 0.0
var mana: float = 0.0
## Lệnh hiện tại (CMD-03); chỉ CommandSystem đặt.
var order: Order = Order.idle()
