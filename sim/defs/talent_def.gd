class_name TalentDef
extends Resource
## Tầng II của một kỹ năng, chọn ở cấp `talent_level` (TAL-01..04).

@export var id: StringName
@export var display_name: String
@export var description: String
@export var value_changes: Array[ValueChangeDef] = []
## Nối vào cuối `on_cast` của kỹ năng (TAL-02b).
@export var extra_actions: Array[ActionDef] = []
@export var effect_patches: Array[EffectPatchDef] = []
