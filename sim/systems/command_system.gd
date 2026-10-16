class_name CommandSystem
extends SimSystem
## Pha 1: áp lệnh đang chờ theo thứ tự gửi (CMD-01), từ chối lệnh không hợp lệ kèm lý
## do (CMD-02), lệnh mới thay lệnh cũ (CMD-03), ghi nhật ký (CMD-04). ATTACK_AUTO chọn
## mục tiêu lúc áp (CMD-05, CTL-02/03), khóa mục tiêu (CTL-04). CAST kiểm tra ABL-02.


func run(world: World) -> void:
	world.rejected_commands.clear()
	for command: Command in world.take_pending_commands():
		command.tick = world.tick
		var unit: Entity = world.find_entity(command.entity_id)
		command.reject_reason = _check(world, command, unit)
		if command.reject_reason != Command.Reject.NONE:
			world.rejected_commands.append(command)
			continue
		if command.type == Command.Type.BUY or command.type == Command.Type.SELL:
			if command.type == Command.Type.BUY:
				Shop.buy(world, unit, command.item_id)  # SHOP-01
			else:
				Shop.sell(world, unit, command.slot)  # SHOP-05
			world.command_log.append(command)
			continue
		if command.type == Command.Type.LEVEL_UP or command.type == Command.Type.CHOOSE_TALENT:
			if command.type == Command.Type.LEVEL_UP:
				Progression.spend_point(world, unit, command.slot)  # không đổi lệnh hiện tại
			else:
				Progression.choose_talent(world, unit, command.slot)
			world.command_log.append(command)
			continue
		var order: Order = _order_for(world, command, unit)
		if unit.cast != null or unit.dash != null:
			unit.queued_order = order  # D-59, ABL-08: đang tung chiêu / lướt, lệnh chờ tới khi xong
		else:
			unit.order = order
		world.command_log.append(command)


func _order_for(world: World, command: Command, unit: Entity) -> Order:
	match command.type:
		Command.Type.MOVE_TO:
			return Order.move(command.point)
		Command.Type.MOVE_DIR:
			return Order.direct(command.direction)
		Command.Type.ATTACK:
			if command.lock:
				unit.lock_target_id = command.target_id
			return Order.attack(command.target_id)
		Command.Type.ATTACK_AUTO:
			return _auto_order(world, unit, command.mode)
		Command.Type.CAST:
			return Order.cast(command.slot, command.target_id, _clamped_point(unit, command), command.direction)
	return Order.idle()


## D-59 (kiểu Liên Quân): điểm xa quá tầm chiêu kéo về mép tầm, tung ngay tại đó.
func _clamped_point(unit: Entity, command: Command) -> Vector2:
	if not command.point.is_finite():
		return command.point
	var a: AbilityInstance = Abilities.of(unit, command.slot)
	var reach: float = Abilities.value(unit, a, &"cast_range")
	var offset: Vector2 = command.point - unit.position
	return unit.position + offset.limit_length(reach) if reach > 0.0 else command.point


func _check(world: World, command: Command, unit: Entity) -> Command.Reject:
	if unit == null:
		return Command.Reject.UNKNOWN_UNIT
	if not unit.alive and not command.type in [Command.Type.LEVEL_UP, Command.Type.CHOOSE_TALENT, Command.Type.BUY, Command.Type.SELL]:
		return Command.Reject.UNIT_DEAD  # cộng điểm được cả khi đang chờ hồi sinh
	if command.type == Command.Type.MOVE_TO:
		if not command.point.is_finite():
			return Command.Reject.POINT_OUTSIDE_MAP
		if world.map != null and not world.map.world_rect().has_point(command.point):
			return Command.Reject.POINT_OUTSIDE_MAP
	if command.type == Command.Type.ATTACK and not Rules.is_attackable(unit, world.find_entity(command.target_id)):
		return Command.Reject.BAD_TARGET
	if command.type == Command.Type.MOVE_DIR:
		if not command.direction.is_finite() or command.direction.length() < 0.000001:
			return Command.Reject.BAD_DIRECTION
	if command.type == Command.Type.CAST:
		return _check_cast(world, command, unit)
	if command.type == Command.Type.LEVEL_UP:
		return Progression.level_problem(world, unit, command.slot)
	if command.type == Command.Type.CHOOSE_TALENT:
		return Progression.talent_problem(world, unit, command.slot)
	if command.type == Command.Type.BUY:
		return Shop.buy_problem(world, unit, command.item_id)
	if command.type == Command.Type.SELL:
		return Shop.sell_problem(unit, command.slot)
	return Command.Reject.NONE


## ABL-02 + kiểu nhắm của kỹ năng.
func _check_cast(world: World, command: Command, unit: Entity) -> Command.Reject:
	var a: AbilityInstance = Abilities.of(unit, command.slot)
	var problem: Abilities.Problem = Abilities.problem(world, unit, a)
	if problem != Abilities.Problem.NONE:
		return [Command.Reject.NONE, Command.Reject.NOT_LEARNED, Command.Reject.ON_COOLDOWN,
			Command.Reject.NO_MANA, Command.Reject.CANNOT_CAST, Command.Reject.BAD_TARGET][problem]
	match a.def.targeting:
		AbilityDef.Targeting.UNIT:
			if not Abilities.accepts(unit, a.def, world.find_entity(command.target_id)):
				return Command.Reject.BAD_TARGET
		AbilityDef.Targeting.POINT:
			if not command.point.is_finite() or (world.map != null and not world.map.world_rect().has_point(command.point)):
				return Command.Reject.POINT_OUTSIDE_MAP
		AbilityDef.Targeting.DIRECTION:
			if not command.direction.is_finite() or command.direction.length() < 0.000001:
				return Command.Reject.BAD_DIRECTION
	return Command.Reject.NONE


func _auto_order(world: World, unit: Entity, mode: int) -> Order:
	if unit.lock_target_id >= 0 and not Rules.lock_holds(world, unit):
		unit.lock_target_id = -1  # CTL-04: hết khóa
	var target: int = Rules.pick_attack_target(world, unit, mode as Rules.AttackMode)
	return Order.attack(target) if target >= 0 else Order.swing()
