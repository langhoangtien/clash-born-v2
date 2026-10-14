class_name AttackSystem
extends SimSystem
## Pha 8: đánh thường (CMB-01, CMB-06). Vung tay `attack_point / tốc đánh`, cuối lúc vung
## ra đòn: cận chiến tạo DamageRequest ngay, đánh xa bắn đạn bay theo mục tiêu. Hai đòn
## cách nhau `1 / số đòn mỗi giây`. Đổi lệnh hoặc mục tiêu ra khỏi tầm khi đang vung → hủy,
## không tính hồi đòn. Lệnh SWING: đánh gió tại chỗ, không sát thương (D-46). Chỉ hệ thống
## này ghi trạng thái đánh và danh sách đạn.


func run(world: World) -> void:
	for e: Entity in world.entities:
		if e.alive and e.stats != null:
			_update_attacker(world, e)
	_update_projectiles(world)


func _update_attacker(world: World, e: Entity) -> void:
	var attacking: bool = e.order.type == Order.Type.ATTACK and not e.order.finished
	var swinging: bool = e.order.type == Order.Type.SWING and not e.order.finished
	var wanted: int = e.order.target_id if attacking else -1
	if e.attack_phase == Entity.AttackPhase.WINDUP and (not (attacking or swinging) or wanted != e.attack_target_id):
		e.attack_phase = Entity.AttackPhase.NONE  # CMB-06: hủy
	if e.attack_phase == Entity.AttackPhase.RECOVERY and world.tick >= e.next_attack_tick:
		e.attack_phase = Entity.AttackPhase.NONE
	if not Rules.can_attack(e):
		if e.attack_phase == Entity.AttackPhase.WINDUP:
			e.attack_phase = Entity.AttackPhase.NONE  # ST-01/04/11: hủy, không tốn hồi đòn
		return
	if e.order.type == Order.Type.SWING and not e.order.finished:
		_update_swing(world, e)
		return
	if not attacking:
		return
	var target: Entity = world.find_entity(e.order.target_id)
	if not Rules.is_attackable(e, target):
		e.order.finished = true
		e.attack_phase = Entity.AttackPhase.NONE if e.attack_phase == Entity.AttackPhase.WINDUP else e.attack_phase
		return
	if e.attack_phase == Entity.AttackPhase.WINDUP:
		if not Rules.in_attack_range(e, target):
			e.attack_phase = Entity.AttackPhase.NONE
		elif world.tick >= e.attack_release_tick:
			_release(world, e, target)
		return
	if e.attack_phase == Entity.AttackPhase.NONE and Rules.in_attack_range(e, target) and world.tick >= e.next_attack_tick:
		_start_windup(world, e, target)


## D-46: chờ hết hồi đòn, vung theo hướng đang nhìn, ra đòn không trúng ai rồi xong lệnh.
func _update_swing(world: World, e: Entity) -> void:
	if e.attack_phase == Entity.AttackPhase.NONE and world.tick >= e.next_attack_tick:
		_start_windup(world, e, null)
	elif e.attack_phase == Entity.AttackPhase.WINDUP and world.tick >= e.attack_release_tick:
		_finish_attack(e)
		e.order.finished = true


func _start_windup(world: World, e: Entity, target: Entity) -> void:
	var speed: float = maxf(0.01, e.stats.get_stat(StatId.Id.ATTACK_SPEED))
	e.attack_phase = Entity.AttackPhase.WINDUP
	e.attack_target_id = target.id if target != null else -1
	e.attack_start_tick = world.tick
	e.attack_release_tick = world.tick + maxi(1, SimClock.seconds_to_ticks(e.attack_point / speed))
	if target != null and target.position != e.position:
		e.facing = (target.position - e.position).normalized()
	e.attack_crit = _roll_crit(world, e, target)
	if target != null:
		if e.last_attack_target_id >= 0 and e.last_attack_target_id != target.id:
			world.emit(&"attack_target_changed", e.id, target.id)  # CMB-12
		e.last_attack_target_id = target.id
	world.emit(&"attack_started", e.id, e.attack_target_id, e.attack_crit)


## CMB-07: mỗi nguồn chí mạng tung PRD riêng; nhiều nguồn trúng thì lấy hệ số cao nhất.
## Không chí mạng lên công trình và đánh gió.
func _roll_crit(world: World, e: Entity, target: Entity) -> float:
	if target == null or Rules.is_structure(target):
		return 1.0
	var best: float = 1.0
	for inst: EffectInstance in e.effects:
		if inst.def.crit_chance.is_empty():
			continue
		var ctx: ExprContext = Effects.context(world, e, inst)
		if Prd.roll(world, Prd.key(e.id, inst.serial * 16 + 15), ExprEval.evaluate(inst.def.crit_chance, ctx)):
			best = maxf(best, ExprEval.evaluate(inst.def.crit_multiplier, ctx))
	return best


## Hồi đòn chỉ tính khi đòn đã ra (CMB-06): đòn bị hủy không tốn hồi đòn.
func _finish_attack(e: Entity) -> void:
	e.attack_phase = Entity.AttackPhase.RECOVERY
	e.next_attack_tick = e.attack_start_tick + maxi(1, SimClock.seconds_to_ticks(1.0 / e.stats.attacks_per_second()))


func _release(world: World, e: Entity, target: Entity) -> void:
	_finish_attack(e)
	var request: DamageRequest = DamageRequest.attack(e, target.id)
	request.raw *= e.attack_crit
	request.crit = e.attack_crit > 1.0
	if e.projectile_speed <= 0.0:
		world.damage_requests.append(request)
		return
	var p: Projectile = Projectile.new()
	p.source_id = e.id
	p.target_id = target.id
	p.position = e.position
	p.speed = e.projectile_speed
	p.request = request
	world.projectiles.append(p)


## Đạn bay thẳng tới vị trí hiện tại của mục tiêu; mục tiêu mất thì đạn mất.
func _update_projectiles(world: World) -> void:
	var flying: Array[Projectile] = []
	for p: Projectile in world.projectiles:
		var target: Entity = world.find_entity(p.target_id)
		if target == null or not target.alive:
			continue
		var step: float = p.speed * SimClock.TICK_SECONDS
		var gap: float = p.position.distance_to(target.position) - target.radius
		if gap <= step:
			world.damage_requests.append(p.request)
			continue
		p.position += (target.position - p.position).normalized() * step
		flying.append(p)
	world.projectiles = flying
