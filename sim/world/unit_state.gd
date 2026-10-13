class_name UnitState
extends RefCounted
## Mã trạng thái (GAME_RULES mục ST). Thêm trạng thái = thay đổi luật (ST-10).

enum Id {
	STUNNED,       # ST-01
	ROOTED,        # ST-02
	SILENCED,      # ST-03
	DISARMED,      # ST-04
	INVISIBLE,     # ST-05
	REVEALED,      # ST-06
	INVULNERABLE,  # ST-07
	DEAD,          # ST-08
	GHOST,         # ST-11
	UNTARGETABLE,  # ST-12
	MAGIC_IMMUNE,  # ST-15
	HEXED,         # ST-16
}
