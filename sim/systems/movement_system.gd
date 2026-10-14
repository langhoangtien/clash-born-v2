class_name MovementSystem
extends SimSystem
## Pha 6: đi theo lệnh MOVE (MOV-01..03) rồi đẩy tách các đơn vị chồng nhau (MOV-04).
## Không bao giờ đặt đơn vị vào vật cản (MOV-05, INV-01). Chỉ hệ thống này đổi vị trí.

## Hằng số kỹ thuật: hai tâm gần hơn mức này coi như trùng nhau.
const SAME_SPOT: float = 0.001
## Lệnh đánh: mục tiêu dịch đi quá chừng này (đơn vị thế giới) thì tìm đường lại.
const RETARGET_DISTANCE: float = 48.0
## Lọc thô khi đẩy nhau: đơn vị có thể đã dời trong bước đẩy (tối đa 2 × separation một tick).
const SEPARATION_SLACK: float = 32.0
## MOV-06: góc thử khi trượt dọc mép (độ), góc nhỏ trước, + trước −.
const SLIDE_ANGLES: Array[float] = [15.0, -15.0, 30.0, -30.0, 45.0, -45.0, 60.0, -60.0, 75.0, -75.0]

## Số lần một bước đi bị chặn vì sẽ vào vật cản (phải luôn bằng 0 nếu tìm đường đúng;
## test kiểm tra). Khi xảy ra, đơn vị đứng lại và tìm đường lại ở tick sau.
var blocked_steps: int = 0


func run(world: World) -> void:
	for e: Entity in world.entities:
		if Rules.is_structure(e) or not Rules.can_move(e):
			continue  # công trình không bao giờ di chuyển; hero chờ hồi sinh nằm yên (ECO-04)
		if e.order.type == Order.Type.MOVE and not e.order.finished:
			_advance(world, e)
		elif e.order.type == Order.Type.DIRECT:
			_advance_direct(world, e)
		elif e.order.type == Order.Type.ATTACK and not e.order.finished:
			_advance_attack(world, e)
	_separate(world)


func _advance(world: World, e: Entity) -> void:
	var nav: MapNavigation = world.navigation(e.radius)
	if e.path_for != e.order or (e.path_dirty and not _path_still_walkable(nav, e)):
		_plan(nav, e)
	e.path_dirty = false
	_walk_path(nav, e, e.stats.get_stat(StatId.Id.MOVEMENT_SPEED) * SimClock.TICK_SECONDS, null)
	if e.path_index >= e.path.size():
		e.order.finished = true  # MOV-03
		e.path = PackedVector2Array()


## CMB-01: lệnh đánh — mục tiêu ngoài tầm thì đi tới, vào tầm (hoặc đang vung tay) thì đứng.
## Mục tiêu dịch đi quá RETARGET_DISTANCE thì tìm đường lại.
func _advance_attack(world: World, e: Entity) -> void:
	var target: Entity = world.find_entity(e.order.target_id)
	if target == null or e.attack_phase == Entity.AttackPhase.WINDUP or Rules.in_attack_range(e, target):
		e.path = PackedVector2Array()
		e.path_index = 0
		return
	var nav: MapNavigation = world.navigation(e.radius)
	if e.path_for != e.order or e.path_goal.distance_to(target.position) > RETARGET_DISTANCE \
			or e.path_index >= e.path.size() or (e.path_dirty and not _path_still_walkable(nav, e)):
		e.path_for = e.order
		e.path_goal = target.position
		e.path_index = 1
		var goal: Vector2 = target.position if nav.point_is_clear(target.position) else nav.nearest_clear(target.position)
		e.path = nav.path(e.position, goal)
	e.path_dirty = false
	_walk_path(nav, e, e.stats.get_stat(StatId.Id.MOVEMENT_SPEED) * SimClock.TICK_SECONDS, target)


## MOV-06: đi thẳng theo hướng; bị chặn thì trượt dọc mép.
func _advance_direct(world: World, e: Entity) -> void:
	var nav: MapNavigation = world.navigation(e.radius)
	var budget: float = e.stats.get_stat(StatId.Id.MOVEMENT_SPEED) * SimClock.TICK_SECONDS
	e.facing = e.order.direction
	if budget <= 0.0:
		return
	var step: Vector2 = e.order.direction * budget
	if _try_step(nav, e, step):
		return
	for angle: float in SLIDE_ANGLES:
		var radians: float = deg_to_rad(angle)
		if _try_step(nav, e, step.rotated(radians) * cos(radians)):
			return


func _try_step(nav: MapNavigation, e: Entity, offset: Vector2) -> bool:
	var target: Vector2 = e.position + offset
	if not nav.point_is_clear(target) or not nav.has_line_of_walk(e.position, target):
		return false
	e.position = target
	return true


## MOV-02: điểm đến không đứng được thì lấy điểm đứng được gần nhất.
func _plan(nav: MapNavigation, e: Entity) -> void:
	e.path_for = e.order
	e.path_index = 1
	var target: Vector2 = e.order.point
	if not nav.point_is_clear(target):
		target = nav.nearest_clear(target)
	e.path = nav.path(e.position, target) if nav.point_is_clear(target) else PackedVector2Array()


func _path_still_walkable(nav: MapNavigation, e: Entity) -> bool:
	return e.path_index >= e.path.size() or nav.has_line_of_walk(e.position, e.path[e.path_index])


## MOV-04: từng cặp theo id; mỗi bên lùi một nửa phần chồng (tối đa separation_speed);
## bên bị chặn đứng yên thì bên kia nhận hết.
func _separate(world: World) -> void:
	var max_push: float = world.balance.separation_speed * SimClock.TICK_SECONDS
	for a: Entity in world.entities:
		if not a.alive:
			continue
		# Lưới dựng một lần ở đầu bước đẩy; vị trí đổi trong lúc đẩy chỉ làm lọc thô kém đi
		# vài đơn vị, kết quả vẫn xác định vì thứ tự theo id.
		var later: Array[Entity] = []
		for b: Entity in world.spatial_near(a.position, a.radius + SEPARATION_SLACK, World.Phase.MOVEMENT, false):
			if b.id > a.id:
				later.append(b)
		if later.size() > 1:
			later.sort_custom(func(x: Entity, y: Entity) -> bool: return x.id < y.id)
		for b: Entity in later:
			var overlap: float = a.radius + b.radius - a.position.distance_to(b.position)
			if overlap > 0.0:
				_push_pair(world, a, b, overlap, max_push)


func _push_pair(world: World, a: Entity, b: Entity, overlap: float, max_push: float) -> void:
	var dir: Vector2 = b.position - a.position
	if dir.length() < SAME_SPOT:
		# Trùng tâm: hướng cố định theo id để kết quả xác định (D-30).
		dir = Vector2.from_angle(float((a.id * 7919 + b.id * 104729) % 360) * PI / 180.0)
	dir = dir.normalized()
	var half: float = minf(overlap * 0.5, max_push)
	var a_moved: bool = _try_push(world, a, -dir * half)
	var b_moved: bool = _try_push(world, b, dir * half)
	if a_moved and not b_moved:
		_try_push(world, a, -dir * minf(overlap - half, max_push))
	elif b_moved and not a_moved:
		_try_push(world, b, dir * minf(overlap - half, max_push))


func _try_push(world: World, e: Entity, offset: Vector2) -> bool:
	if e.kind == Entity.Kind.TOWER or e.kind == Entity.Kind.CORE:
		return false
	var nav: MapNavigation = world.navigation(e.radius)
	var target: Vector2 = e.position + offset
	if not nav.point_is_clear(target) or not nav.has_line_of_walk(e.position, target):
		return false
	e.position = target
	e.path_dirty = true
	return true

## Đi dọc đường hiện có với quãng `budget`; dừng sớm khi `stop_near` vào tầm đánh.
func _walk_path(nav: MapNavigation, e: Entity, budget: float, stop_near: Entity) -> void:
	while budget > 0.0 and e.path_index < e.path.size():
		var next: Vector2 = e.path[e.path_index]
		var gap: float = e.position.distance_to(next)
		var step_to: Vector2 = next if gap <= budget else e.position + (next - e.position) / gap * budget
		if not nav.point_is_clear(step_to):
			blocked_steps += 1
			e.path_for = null  # MOV-05: không bước vào vật cản; tick sau tìm đường lại
			return
		if step_to != e.position:
			e.facing = (step_to - e.position).normalized()
		e.position = step_to
		if gap <= budget:
			budget -= gap
			e.path_index += 1
		else:
			budget = 0.0
		if stop_near != null and Rules.in_attack_range(e, stop_near):
			return
