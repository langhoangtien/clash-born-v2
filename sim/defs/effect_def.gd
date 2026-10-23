class_name EffectDef
extends GameDef
## Mọi buff, debuff, trạng thái (ARCHITECTURE 3.3, mục EFF).

enum Stacking { REFRESH, STACK, INDEPENDENT }
enum Dispel { BASIC, STRONG, NONE }  # EFF-07

## Rỗng = thời lượng do hành động áp hiệu ứng truyền vào; "0" = vĩnh viễn.
@export var duration: String
@export var stacking: Stacking = Stacking.REFRESH
@export var max_stacks: int = 1
@export var tags: Array[StringName] = []
@export var dispel: Dispel = Dispel.BASIC
@export var states: Array[UnitState.Id] = []
@export var modifiers: Array[ModifierDef] = []
## EFF-16 (D-135): modifier tính lại mỗi tick theo trạng thái hiện tại của chủ.
@export var live: bool = false
@export var triggers: Array[TriggerDef] = []
@export var removed_by: Array[StringName] = []  # EFF-05
## State chỉ có hiệu lực sau khoảng này (tàng hình).
@export var fade_in: String
## Lượng khiên (EFF-06). Rỗng = không phải khiên.
@export var absorb: String
## DTH-01: chặn cái chết của chủ hiệu ứng (kiểu Wraith King). Gắn với kỹ năng bị động thì cần
## kỹ năng đã hồi và đủ mana; không gắn kỹ năng nào thì dùng một lần rồi mất (kiểu Aegis).
@export var prevent_death: bool = false
@export var periodic_interval: String
@export var periodic_actions: Array[ActionDef] = []
## Chí mạng của đòn đánh (CMB-07). Rỗng = không chí mạng.
@export var crit_chance: String
@export var crit_multiplier: String
