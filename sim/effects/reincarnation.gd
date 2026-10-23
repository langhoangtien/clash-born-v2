class_name Reincarnation
extends RefCounted
## DTH-01..03: chặn chết bằng hiệu ứng `prevent_death` và tái sinh tại chỗ.


## DTH-01: `e` vừa về 0 máu. Có hiệu ứng `prevent_death` dùng được thì chặn chết: phát
## `lethal_damage`, máu giữ 1, nằm chờ `reincarnate_delay` (DTH-02), tính thưởng hạ (DTH-03).
static func try_prevent(world: World, e: Entity, source_id: int) -> bool:
	if e.kind != Entity.Kind.HERO:
		return false
	for inst: EffectInstance in e.effects:
		if not inst.def.prevent_death:
			continue
		var a: AbilityInstance = _ability_of(e, inst)
		if a != null:
			var cost: float = Abilities.value(e, a, &"mana")
			if world.tick < a.ready_tick or e.mana < cost:
				continue
			e.mana -= cost
			a.ready_tick = world.tick + Abilities.cooldown_ticks(e, a)  # ABL-19
		else:
			Effects.remove(world, e, inst, &"removed")  # dùng một lần (kiểu Aegis)
		_lie_down(world, e, source_id)
		return true
	return false


## DTH-02: hết thời gian nằm → đầy máu, đầy mana, gỡ mọi debuff, phát `reincarnated`.
static func stand_up(world: World, e: Entity) -> void:
	e.reincarnate_tick = -1
	for inst: EffectInstance in e.effects.duplicate():
		if inst.def.tags.has(&"debuff"):
			Effects.remove(world, e, inst, &"dispelled")
	Effects.refresh_states(e)
	e.health = e.stats.get_stat(StatId.Id.MAX_HP)
	e.mana = e.stats.get_stat(StatId.Id.MAX_MANA)
	world.emit(&"reincarnated", -1, e.id)


static func _lie_down(world: World, e: Entity, source_id: int) -> void:
	e.health = 1.0
	e.killer_id = source_id
	e.reincarnate_tick = world.tick + SimClock.seconds_to_ticks(world.balance.reincarnate_delay)
	e.order = Order.idle()
	e.queued_order = null
	e.cast = null
	e.path = PackedVector2Array()
	e.path_index = 0
	e.attack_phase = Entity.AttackPhase.NONE
	e.lock_target_id = -1
	Effects.refresh_states(e)
	world.emit(&"lethal_damage", source_id, e.id)
	world.note(&"reincarnate", e.position)
	DeathSystem.hero_kill_rewards(world, e, false)  # DTH-03


## Kỹ năng bị động (của hero hoặc món đồ) đã áp hiệu ứng `inst`, null nếu không có.
static func _ability_of(e: Entity, inst: EffectInstance) -> AbilityInstance:
	for a: AbilityInstance in e.abilities:
		if a.learned_effects.has(inst):
			return a
	for it: ItemInstance in Items.slots(e):
		if it != null and it.ability != null and it.ability.learned_effects.has(inst):
			return it.ability
	return null
