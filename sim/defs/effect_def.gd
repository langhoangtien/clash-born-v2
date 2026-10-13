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
@export var triggers: Array[TriggerDef] = []
@export var removed_by: Array[StringName] = []  # EFF-05
## State chỉ có hiệu lực sau khoảng này (tàng hình).
@export var fade_in: String
## Lượng khiên (EFF-06). Rỗng = không phải khiên.
@export var absorb: String
@export var periodic_interval: String
@export var periodic_actions: Array[ActionDef] = []
## Chí mạng của đòn đánh (CMB-07). Rỗng = không chí mạng.
@export var crit_chance: String
@export var crit_multiplier: String
