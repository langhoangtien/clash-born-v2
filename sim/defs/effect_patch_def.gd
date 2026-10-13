class_name EffectPatchDef
extends Resource
## Talent gắn thêm trigger/modifier vào một hiệu ứng của kỹ năng (TAL-02c).
## Không đổi state (TAL-03).

@export var effect: EffectDef
@export var add_triggers: Array[TriggerDef] = []
@export var add_modifiers: Array[ModifierDef] = []
