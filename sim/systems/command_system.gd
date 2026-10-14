class_name CommandSystem
extends SimSystem
## Pha 1: áp lệnh đang chờ theo thứ tự gửi (CMD-01), từ chối lệnh không hợp lệ kèm lý
## do (CMD-02), lệnh mới thay lệnh cũ (CMD-03), ghi nhật ký (CMD-04). ATTACK_AUTO chọn
## mục tiêu lúc áp (CMD-05, CTL-02/03), khóa mục tiêu (CTL-04).


func run(world: World) -> void:
	world.rejected_commands.clear()
	for command: Command in world.take_pending_commands():
		command.tick = world.tick
		var unit: Entity = world.find_entity(command.entity_id)
		command.reject_reason = _check(world, command, unit)
		if command.reject_reason != Command.Reject.NONE:
			world.rejected_commands.append(command)
			continue
		match command.type:
			Command.Type.MOVE_TO:
				unit.order = Order.move(command.point)
			Command.Type.MOVE_DIR:
				unit.order = Order.direct(command.direction)
			Command.Type.ATTACK:
				unit.order = Order.attack(command.target_id)
				if command.lock:
					unit.lock_target_id = command.target_id
			Command.Type.ATTACK_AUTO:
				unit.order = _auto_order(world, unit, command.mode)
			Command.Type.STOP:
				unit.order = Order.idle()
		world.command_log.append(command)


func _check(world: World, command: Command, unit: Entity) -> Command.Reject:
	if unit == null:
		return Command.Reject.UNKNOWN_UNIT
	if not unit.alive:
		return Command.Reject.UNIT_DEAD
	if command.type == Command.Type.MOVE_TO:
		if not command.point.is_finite():
			return Command.Reject.POINT_OUTSIDE_MAP
		if world.map != null and not world.map.world_rect().has_point(command.point):
			return Command.Reject.POINT_OUTSIDE_MAP
	if command.type == Command.Type.ATTACK and not Rules.is_targetable(unit, world.find_entity(command.target_id)):
		return Command.Reject.BAD_TARGET
	if command.type == Command.Type.MOVE_DIR:
		if not command.direction.is_finite() or command.direction.length() < 0.000001:
			return Command.Reject.BAD_DIRECTION
	return Command.Reject.NONE


func _auto_order(world: World, unit: Entity, mode: int) -> Order:
	if unit.lock_target_id >= 0 and not Rules.lock_holds(world, unit):
		unit.lock_target_id = -1  # CTL-04: hết khóa
	var target: int = Rules.pick_attack_target(world, unit, mode as Rules.AttackMode)
	return Order.attack(target) if target >= 0 else Order.swing()
