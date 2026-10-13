class_name UnitDef
extends GameDef
## Lính, quái rừng, công trình.

enum Kind { CREEP_MELEE, CREEP_RANGED, CREEP_SIEGE, NEUTRAL, TOWER, CORE }

@export var kind: Kind = Kind.CREEP_MELEE
@export var stats: CombatStatsDef
@export var bounty_gold: int
@export var bounty_xp: int
@export var abilities: Array[AbilityDef] = []
