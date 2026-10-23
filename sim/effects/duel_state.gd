class_name DuelState
extends RefCounted
## Một Quyết Đấu đang diễn ra (DUL, D-135). Hai bên dùng chung bản này qua Entity.duel.
## Chỉ Duels tạo / kết thúc.

## A: người tung (nhận hiệu ứng riêng, phản sát thương); B: đối thủ.
var knight_id: int = -1
var foe_id: int = -1
var end_tick: int = 0
## DUL-01: giá trị chụp lúc bắt đầu — duration, reflect, win_damage, lose_damage, win_gold.
var values: Dictionary[StringName, float] = {}
## DUL-08: hiệu ứng do Quyết Đấu áp (gỡ khi kết thúc).
var effects: Array[EffectInstance] = []


func other(id: int) -> int:
	return foe_id if id == knight_id else knight_id
