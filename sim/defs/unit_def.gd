class_name UnitDef
extends GameDef
## Lính, quái rừng, công trình.

enum Kind { CREEP_MELEE, CREEP_RANGED, CREEP_SIEGE, NEUTRAL, TOWER, CORE, WARD }

@export var kind: Kind = Kind.CREEP_MELEE
@export var stats: CombatStatsDef
@export var bounty_gold: int
@export var bounty_xp: int
@export var abilities: Array[AbilityDef] = []
## WRD-02: ward tồn tại bao nhiêu giây (0 = mãi).
@export var lifetime: float
## WRD-03: bán kính nhìn thấy tàng hình (mắt xanh).
@export var true_sight_range: float
