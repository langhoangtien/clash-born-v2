class_name EconomySystem
extends SimSystem
## Pha 12: vàng thụ động (ECO-01): cứ `passive_gold_interval` giây (tính từ tick 0) mỗi hero
## được `passive_gold`, kể cả khi đang chờ hồi sinh. Vàng last hit / trụ ở DeathSystem.


func run(world: World) -> void:
	Shop.restock(world)  # SHOP-08
	if world.balance.passive_gold_interval <= 0.0 or world.balance.passive_gold == 0:
		return
	if world.tick % maxi(1, SimClock.seconds_to_ticks(world.balance.passive_gold_interval)) != 0:
		return
	for e: Entity in world.entities:
		if e.kind == Entity.Kind.HERO:
			e.gold += world.balance.passive_gold
