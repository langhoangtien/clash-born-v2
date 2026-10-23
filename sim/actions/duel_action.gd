class_name DuelAction
extends ActionDef
## Quyết Đấu (DUL-01, D-135) giữa chủ kỹ năng và `target`. Bắt đầu được thì chạy `on_start`.

@export var duration: String
@export var reflect: String
@export var win_damage: String
@export var lose_damage: String
@export var win_gold: String
## Áp lên cả hai (state DUELING, ST-19).
@export var duel_effect: EffectDef
## Áp lên chủ kỹ năng trong lúc đấu (vd +tốc đánh).
@export var self_effect: EffectDef
@export var on_start: Array[ActionDef] = []
