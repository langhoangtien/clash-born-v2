class_name Entity
extends RefCounted
## Một đơn vị trên sân (ARCHITECTURE 3.1). Chỉ có các trường mà hệ thống hiện có cần;
## thêm trường khi hệ thống dùng nó được làm (không làm trước).

enum Kind { HERO, LANE_CREEP, NEUTRAL, TOWER, CORE }
enum AttackPhase { NONE, WINDUP, RECOVERY }

## Do World cấp, tăng dần, không dùng lại; quyết định thứ tự xử lý.
var id: int = -1
var team: int = 0  # 0 Blue, 1 Red, 2 trung lập
var kind: Kind = Kind.HERO
var position: Vector2 = Vector2.ZERO
var radius: float = 0.0
## Hướng nhìn (MovementSystem ghi khi đi). VIEW dùng để quay hình.
var facing: Vector2 = Vector2.RIGHT
## Id hình (ART.md); SIM không biết đường dẫn file.
var art_id: StringName
## Công trình: id trên map (vd "blue_mid_t1", "core_0"), bậc (1–4, nhà chính 5), khóa (STR-02).
var structure_id: StringName
var tier: int = 0
var locked: bool = false
## Trụ: hero địch vừa gây giao tranh hero phe trụ và hạn nhớ (STR-01, StructureController ghi).
## Lính đường: lane, có phải lính công thành (CRP-10), đang về lane (CRP-07), origin leash (DEF-08).
var lane: String = ""
var siege: bool = false
var returning: bool = false
var return_point: Vector2 = Vector2.ZERO
var has_origin: bool = false
var chase_origin: Vector2 = Vector2.ZERO
var aggro_target_id: int = -1
var aggro_until_tick: int = 0
var stats: StatBlock
var health: float = 0.0
var mana: float = 0.0
## Còn sống; chỉ DamageSystem đặt false (DeathSystem gỡ đơn vị sau đó).
var alive: bool = true
## Nhịp đánh (CMB-06), từ dữ liệu: thời điểm ra đòn (giây, trước tốc đánh); tốc đạn (0 = cận chiến).
var attack_point: float = 0.0
var projectile_speed: float = 0.0
## Trạng thái đánh (chỉ AttackSystem ghi).
var attack_phase: AttackPhase = AttackPhase.NONE
var attack_target_id: int = -1
var attack_start_tick: int = 0
var attack_release_tick: int = 0
var next_attack_tick: int = 0
## Lệnh hiện tại (CMD-03); chỉ CommandSystem đặt.
var order: Order = Order.idle()
## Đường đang đi (chỉ MovementSystem ghi). `path_for` = lệnh mà đường này phục vụ.
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var path_for: Order
var path_goal: Vector2 = Vector2.ZERO
## Bị đẩy lệch (MOV-04): tick sau kiểm tra còn đi thẳng tới điểm kế tiếp được không.
var path_dirty: bool = false
