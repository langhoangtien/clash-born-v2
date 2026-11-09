class_name UnitDef
extends GameDef
## Lính, quái rừng, công trình.

enum Kind { CREEP_MELEE, CREEP_RANGED, CREEP_SIEGE, NEUTRAL, TOWER, CORE, WARD }

@export var kind: Kind = Kind.CREEP_MELEE
@export var stats: CombatStatsDef
@export var bounty_gold: int
@export var bounty_xp: int
## JGL-11 (D-307): mỗi hero phe kẻ hạ nhận thêm chừng này vàng / XP.
@export var team_gold: int
@export var team_xp: int
## JGL-12 (D-307): hiệu ứng mạnh dần, số tầng = số phút trọn của trận.
@export var growth: EffectDef
## JGL-13 (D-307): hiệu ứng thường trực gắn lúc sinh (quái rừng).
@export var passives: Array[EffectDef] = []
@export var abilities: Array[AbilityDef] = []
## WRD-02: ward tồn tại bao nhiêu giây (0 = mãi).
@export var lifetime: float
## WRD-03: bán kính nhìn thấy tàng hình (mắt xanh).
@export var true_sight_range: float
