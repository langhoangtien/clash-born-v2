class_name DamageSystem
extends SimSystem
## Pha 9: trừ máu (CMB-02, CMB-03): sau giáp nhân `damage_taken_multiplier`. Phát
## `attack_landed`, `damage_taken`, và `unit_died` khi máu về 0. Chỉ hệ thống này trừ máu.


func run(world: World) -> void:
	var requests: Array[DamageRequest] = world.damage_requests
	world.damage_requests = []
	for r: DamageRequest in requests:
		var target: Entity = world.find_entity(r.target_id)
		if target == null or not target.alive:
			continue
		var s: StatBlock = target.stats
		var amount: float = DamageFormulas.final_damage(r.raw, r.damage_type,
			s.get_stat(StatId.Id.PHYSICAL_ARMOR), s.get_stat(StatId.Id.MAGIC_ARMOR),
			s.get_stat(StatId.Id.DAMAGE_TAKEN_MULTIPLIER), world.balance)
		if r.is_attack:
			world.emit(&"attack_landed", r.source_id, r.target_id, amount)
		target.health -= amount
		world.emit(&"damage_taken", r.source_id, r.target_id, amount)
		if target.health <= 0.0:
			target.health = 0.0
			target.alive = false
			world.emit(&"unit_died", r.source_id, r.target_id)
