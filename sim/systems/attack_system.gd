class_name AttackSystem
extends SimSystem
## Pha 8: đánh thường (CMB-01, CMB-06). Vung tay `attack_point / tốc đánh`, cuối lúc vung
## ra đòn: cận chiến tạo DamageRequest ngay, đánh xa bắn đạn bay theo mục tiêu. Hai đòn
## cách nhau `1 / số đòn mỗi giây`. Đổi lệnh hoặc mục tiêu ra khỏi tầm khi đang vung → hủy,
## không tính hồi đòn. Chỉ hệ thống này ghi trạng thái đánh và danh sách đạn.


func run(world: World) -> void:
	for e: Entity in world.entities:
		if e.alive and e.stats != null:
			_update_attacker(world, e)
	_update_projectiles(world)


func _update_attacker(world: World, e: Entity) -> void:
	var attacking: bool = e.order.type == Order.Type.ATTACK and not e.order.finished
	if e.attack_phase == Entity.AttackPhase.WINDUP and (not attacking or e.order.target_id != e.attack_target_id):
		e.attack_phase = Entity.AttackPhase.NONE  # CMB-06: hủy
	if e.attack_phase == Entity.AttackPhase.RECOVERY and world.tick >= e.next_attack_tick:
		e.attack_phase = Entity.AttackPhase.NONE
	if not attacking:
		return
	var target: Entity = world.find_entity(e.order.target_id)
	if not Rules.is_targetable(e, target):
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


func _start_windup(world: World, e: Entity, target: Entity) -> void:
	var speed: float = maxf(0.01, e.stats.get_stat(StatId.Id.ATTACK_SPEED))
	e.attack_phase = Entity.AttackPhase.WINDUP
	e.attack_target_id = target.id
	e.attack_start_tick = world.tick
	e.attack_release_tick = world.tick + maxi(1, SimClock.seconds_to_ticks(e.attack_point / speed))
	if target.position != e.position:
		e.facing = (target.position - e.position).normalized()
	world.emit(&"attack_started", e.id, target.id)


func _release(world: World, e: Entity, target: Entity) -> void:
	e.attack_phase = Entity.AttackPhase.RECOVERY
	# Hồi đòn chỉ tính khi đòn đã ra (CMB-06): đòn bị hủy không tốn hồi đòn.
	e.next_attack_tick = e.attack_start_tick + maxi(1, SimClock.seconds_to_ticks(1.0 / e.stats.attacks_per_second()))
	var request: DamageRequest = DamageRequest.attack(e, target.id)
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
