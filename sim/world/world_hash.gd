class_name WorldHash
extends RefCounted
## Mã băm trạng thái World (D-30 phát lại, D-336 so tất định giữa máy, NET-04 so định kỳ khi đánh online). Tách từ
## world.gd (giới hạn 300 dòng); World.state_hash / entity_digest gọi sang đây.


## Băm toàn bộ trạng thái World (tick, RNG, mọi đơn vị, kho cửa hàng, bộ đếm PRD).
static func of(world: World) -> PackedByteArray:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(PackedInt64Array([world.tick, world.rng.seed, world.rng.state, world.entities.size(), world.winner]).to_byte_array())
	for e: Entity in world.entities:
		_hash_entity(ctx, e)
	for t: int in range(world.shop_stock.size()):
		for id: StringName in by_text(world.shop_stock[t].keys()):
			ctx.update(PackedInt64Array([t, id.hash(), world.shop_stock[t][id][0], world.shop_stock[t][id][1]]).to_byte_array())
	var keys: Array = world.prd_counters.keys()
	keys.sort()
	for k: int in keys:
		ctx.update(PackedInt64Array([k, world.prd_counters[k]]).to_byte_array())
	for c: CampState in world.camps:
		ctx.update(PackedInt64Array([c.index, c.unit_ids.size(), c.target_id, c.aggro_until_tick, int(c.returning)]).to_byte_array())
	for a: PendingArea in world.pending_areas:
		ctx.update(PackedFloat64Array([a.source_id, a.due_tick, a.center.x, a.center.y]).to_byte_array())
	for z: ActiveZone in world.zones:
		ctx.update(PackedFloat64Array([z.source_id, z.next_tick, z.end_tick, z.interval_ticks, z.center.x, z.center.y, z.radius]).to_byte_array())
	for s: SkillShot in world.skill_shots:
		ctx.update(PackedFloat64Array([s.source_id, s.position.x, s.position.y, s.direction.x, s.direction.y, s.travelled, s.hit_ids.size()]).to_byte_array())
	for p: Projectile in world.projectiles:
		ctx.update(PackedFloat64Array([p.source_id, p.target_id, p.position.x, p.position.y, p.request.raw]).to_byte_array())
	return ctx.finish()


## D-381: xếp tên theo chữ. `Array.sort()` trên StringName so địa chỉ bộ nhớ → thứ tự đổi theo lần chạy / máy, mã băm
## cùng một trạng thái ra khác nhau (NET-04 báo lệch oan).
static func by_text(names: Array) -> Array:
	var out: Array = names.duplicate()
	out.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	return out


## M9.3 (D-336): mã băm riêng một đơn vị (16 byte đầu SHA-256) — so tất định giữa máy, chỉ ra đơn vị lệch.
static func entity(e: Entity) -> PackedByteArray:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	_hash_entity(ctx, e)
	return ctx.finish().slice(0, 16)


static func _hash_entity(ctx: HashingContext, e: Entity) -> void:
	ctx.update(PackedInt64Array([e.id, e.team, e.kind, e.order.type, int(e.order.finished), e.order.target_id,
		int(e.alive), int(e.locked), int(e.returning), int(e.has_origin), e.aggro_target_id, e.aggro_until_tick, e.attack_phase, e.attack_target_id, e.attack_start_tick, e.attack_release_tick, e.next_attack_tick,
		e.lock_target_id, e.respawn_tick, e.gold, e.last_hits, e.skill_points, e.attribute_bonus_count, e.talent_slot, e.kills, e.deaths, e.assists, e.last_attack_target_id, e.visible_mask, e.bush_id, e.reveal_until_tick, e.camp_index, e.reincarnate_tick, e.expire_tick, e.creep_tier, e.recall_until_tick, e.recall_start_tick]).to_byte_array())
	ctx.update(PackedFloat64Array([e.position.x, e.position.y, e.radius, e.health, e.mana,
		e.order.point.x, e.order.point.y, e.order.direction.x, e.order.direction.y,
		e.chase_origin.x, e.chase_origin.y, e.xp, e.duel_damage]).to_byte_array())
	if e.duel != null:
		ctx.update(PackedInt64Array([e.duel.knight_id, e.duel.foe_id, e.duel.end_tick]).to_byte_array())
	if e.stats != null:
		ctx.update(e.stats.values().to_byte_array())
	for a: AbilityInstance in e.abilities:
		ctx.update(PackedInt64Array([a.slot, a.rank, a.ready_tick]).to_byte_array())
	for it: ItemInstance in e.items:
		if it != null:
			ctx.update(PackedInt64Array([it.index, it.def.id.hash(), it.charges, it.ability.ready_tick if it.ability != null else -1]).to_byte_array())
	if e.knockback != null:
		ctx.update(PackedFloat64Array([e.knockback.direction.x, e.knockback.direction.y, e.knockback.per_tick, e.knockback.end_tick]).to_byte_array())
	if e.dash != null:
		ctx.update(PackedFloat64Array([e.dash.target_id, e.dash.speed, e.dash.source_id]).to_byte_array())
	if e.bot != null:
		ctx.update(PackedFloat64Array([e.bot.mode, e.bot.target_id, e.bot.goal.x, e.bot.goal.y, e.bot.chase_origin.x, e.bot.chase_origin.y, e.bot.trade_until_tick, e.bot.last_hurt_tick, e.bot.upgrades_done, e.bot.last_pos.x, e.bot.last_pos.y, e.bot.last_pos_tick, int(e.bot.ahead)]).to_byte_array())
	if e.cast != null:
		ctx.update(PackedInt64Array([e.cast.ability.slot, e.cast.release_tick, e.cast.target_id]).to_byte_array())
	for inst: EffectInstance in e.effects:
		ctx.update(PackedInt64Array([inst.serial, inst.def.id.hash(), inst.source_id, inst.stacks, inst.end_tick, inst.next_period_tick, inst.active_tick, inst.source_team]).to_byte_array())
		ctx.update(PackedFloat64Array([inst.absorb_left]).to_byte_array())
