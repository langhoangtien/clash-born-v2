class_name RegenSystem
extends SimSystem
## Pha 3 (sau StateSystem): hồi máu / mana mỗi tick theo `hp_regen` / `mana_regen` (mỗi giây),
## không quá tối đa. Đơn vị chết không hồi.


func run(world: World) -> void:
	for e: Entity in world.entities:
		if not e.alive or e.stats == null:
			continue
		var hp_regen: float = e.stats.get_stat(StatId.Id.HP_REGEN)
		if hp_regen != 0.0:
			e.health = clampf(e.health + hp_regen * SimClock.TICK_SECONDS, 0.0, e.stats.get_stat(StatId.Id.MAX_HP))
		var mana_regen: float = e.stats.get_stat(StatId.Id.MANA_REGEN)
		if mana_regen != 0.0:
			e.mana = clampf(e.mana + mana_regen * SimClock.TICK_SECONDS, 0.0, e.stats.get_stat(StatId.Id.MAX_MANA))
