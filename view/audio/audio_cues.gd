class_name AudioCues
extends RefCounted
## VIEW (D-114): đọc sự kiện của tick vừa chạy, trả về các tiếng cần phát. Không phát gì
## (AudioView phát), không ghi gì vào World. Tên tiếng = tên file assets/audio/<id>.ogg.
## - Tiếng có vị trí chỉ phát khi đội người chơi thấy đơn vị liên quan (không lộ qua sương mù).
## - Tiếng giao diện / thông báo không có vị trí.

const SPREE: Dictionary[int, StringName] = {3: &"vo_killing_spree", 4: &"vo_dominating", 5: &"vo_unstoppable"}
const SPREE_MAX: StringName = &"vo_legendary"
const SPREE_SHUT_DOWN: int = 3


class Cue:
	extends RefCounted
	var id: StringName
	## Vị trí trên map; INF = không có vị trí (giao diện / thông báo).
	var at: Vector2 = Vector2.INF
	## Kênh: &"sfx", &"ui", &"vo".
	var group: StringName = &"sfx"
	## Tiếng lặp gắn với `key` (vd về thành của hero id); `stop` = dừng tiếng lặp đó.
	var key: int = -1
	var stop: bool = false


var team: int = 0
var hero_id: int = -1

## Bộ nhớ của tick trước: đơn vị đã bị gỡ khỏi World vẫn còn vị trí / loại / tầm nhìn.
var _pos: Dictionary[int, Vector2] = {}
var _kind: Dictionary[int, int] = {}
var _team: Dictionary[int, int] = {}
var _seen: Dictionary[int, bool] = {}
var _stunned: Dictionary[int, bool] = {}
var _silenced: Dictionary[int, bool] = {}
var _streak: Dictionary[int, int] = {}
var _first_blood: bool = false
var _minions: bool = false
var _started: bool = false
var _ended: bool = false
var _gold: int = -1
var _items: Dictionary[int, bool] = {}
var _w: World


func collect(world: World) -> Array[Cue]:
	_w = world
	var out: Array[Cue] = []
	if not _started:
		_started = true
		_add(out, &"vo_welcome", Vector2.INF, &"vo")
	for ev: GameEvent in world.events:
		_on_event(world, ev, out)
	_states(world, out)
	_own(world, out)
	_remember(world, out)
	if world.winner >= 0 and not _ended:
		_ended = true
		var won: bool = world.winner == team
		_add(out, &"victory" if won else &"defeat", Vector2.INF, &"ui")
		_add(out, &"vo_victory" if won else &"vo_defeat", Vector2.INF, &"vo")
	return out


func _on_event(world: World, ev: GameEvent, out: Array[Cue]) -> void:
	match ev.type:
		&"attack_started":
			_shot(world, ev, out)
		&"attack_landed":
			_hit(world, ev, out)
		&"ability_cast":
			var caster: Entity = world.find_entity(ev.source_id)
			var a: AbilityInstance = Abilities.of(caster, int(ev.amount)) if caster != null else null
			if a != null:
				var sid: StringName = &"item_use" if int(ev.amount) >= Items.SLOT_BASE else StringName("cast_" + String(a.def.id))
				_seen_add(out, sid, ev.source_id)
		&"unit_died":
			_died(ev, out)
		&"unit_spawned":
			if _kind_of(world, ev.target_id) == Entity.Kind.WARD:
				_seen_add(out, &"ward_place", ev.target_id)
		&"kill_credited", &"hero_died":
			_announce(world, ev, out)
		&"structure_destroyed":
			_structure(world, ev, out)
		&"hero_respawned":
			if ev.target_id == hero_id:
				_add(out, &"respawn", Vector2.INF, &"ui")
		&"reincarnated":
			_seen_add(out, &"state_reincarnate", ev.target_id if ev.target_id >= 0 else ev.source_id)
		&"recall_started":
			var c: Cue = _seen_add(out, &"recall_start", ev.source_id)
			if c != null:
				c.key = ev.source_id
		&"recall_cancelled", &"recall_finished":
			var s: Cue = _add(out, &"recall_start", Vector2.INF, &"sfx")
			s.key = ev.source_id
			s.stop = true
			if ev.type == &"recall_finished":
				_seen_add(out, &"recall_finish", ev.source_id)
		&"level_up":
			if ev.source_id == hero_id:
				_add(out, &"ui_level_up", Vector2.INF, &"ui")
		&"skill_leveled":
			if ev.source_id == hero_id:
				_add(out, &"ui_skill_up", Vector2.INF, &"ui")


func _shot(world: World, ev: GameEvent, out: Array[Cue]) -> void:
	var e: Entity = world.find_entity(ev.source_id)
	if e == null:
		return
	if e.kind == Entity.Kind.TOWER:
		_seen_add(out, &"tower_shot", e.id)
	elif e.projectile_speed > 0.0 and e.kind == Entity.Kind.HERO:
		_seen_add(out, &"shot_magic", e.id)
	elif e.projectile_speed > 0.0 and e.kind == Entity.Kind.LANE_CREEP:
		_seen_add(out, &"creep_ranged_shot", e.id)


## Tiếng trúng đòn đánh thường: theo loại kẻ đánh (dữ liệu, không theo id hero).
func _hit(world: World, ev: GameEvent, out: Array[Cue]) -> void:
	var e: Entity = world.find_entity(ev.source_id)
	if e == null:
		return
	var sid: StringName = &""
	if e.kind == Entity.Kind.TOWER:
		sid = &"tower_hit"
	elif e.kind == Entity.Kind.HERO:
		if ev.reason == &"crit":
			sid = &"hit_crit"
		elif e.projectile_speed > 0.0:
			sid = &"hit_magic"
		elif e.hero_def != null and e.hero_def.primary_attribute == StatFormulas.Attribute.AGILITY:
			sid = &"hit_blade"
		else:
			sid = &"hit_melee"
	elif e.projectile_speed <= 0.0:
		sid = &"creep_melee_hit"
	if sid != &"":
		_seen_add(out, sid, ev.target_id)


func _died(ev: GameEvent, out: Array[Cue]) -> void:
	var kind: int = _kind.get(ev.target_id, -1)
	if kind == Entity.Kind.WARD:
		_seen_add(out, &"ward_destroyed", ev.target_id)
	elif kind == Entity.Kind.LANE_CREEP or kind == Entity.Kind.NEUTRAL:
		if _kind.get(ev.source_id, -1) == Entity.Kind.HERO:
			_seen_add(out, &"creep_death", ev.target_id)
		if ev.source_id == hero_id:
			_add(out, &"ui_gold", Vector2.INF, &"ui")


## Thông báo hạ hero kiểu Liên Quân: First Blood, chuỗi hạ gục, Shut down (D-112).
func _announce(world: World, ev: GameEvent, out: Array[Cue]) -> void:
	if ev.type == &"hero_died":
		_seen_add(out, &"hero_death", ev.target_id)
		_streak[ev.target_id] = 0
		return
	var victim_streak: int = _streak.get(ev.target_id, 0)
	if _kind_of(world, ev.source_id) != Entity.Kind.HERO:
		return
	var n: int = _streak.get(ev.source_id, 0) + 1
	_streak[ev.source_id] = n
	if not _first_blood:
		_first_blood = true
		_add(out, &"vo_first_blood", Vector2.INF, &"vo")
	elif victim_streak >= SPREE_SHUT_DOWN:
		_add(out, &"vo_shut_down", Vector2.INF, &"vo")
	elif n >= SPREE_SHUT_DOWN:
		_add(out, SPREE.get(n, SPREE_MAX), Vector2.INF, &"vo")


func _structure(world: World, ev: GameEvent, out: Array[Cue]) -> void:
	var kind: int = _kind_of(world, ev.target_id)
	if kind == Entity.Kind.CORE:
		_add(out, &"core_destroyed", Vector2.INF, &"ui")
		return
	_add(out, &"tower_destroyed", _pos.get(ev.target_id, Vector2.INF), &"sfx")
	var ours: bool = _team.get(ev.target_id, -1) == team
	_add(out, &"vo_ally_tower" if ours else &"vo_enemy_tower", Vector2.INF, &"vo")


## Choáng / câm lặng trên hero thấy được: phát lúc vừa bị dính.
func _states(world: World, out: Array[Cue]) -> void:
	for e: Entity in world.entities:
		if e.kind != Entity.Kind.HERO:
			continue
		var stun: bool = e.alive and Rules.has_state(e, UnitState.Id.STUNNED)
		var silence: bool = e.alive and Rules.has_state(e, UnitState.Id.SILENCED)
		if stun and not _stunned.get(e.id, false):
			_seen_add(out, &"state_stun", e.id)
		elif silence and not _silenced.get(e.id, false):
			_seen_add(out, &"state_silence", e.id)
		_stunned[e.id] = stun
		_silenced[e.id] = silence


## Hero của người chơi: mua / bán (đồ mới + mất vàng / mất đồ + được vàng), lệnh bị từ chối.
func _own(world: World, out: Array[Cue]) -> void:
	for c: Command in world.rejected_commands:
		if c.entity_id == hero_id and c.type in [Command.Type.BUY, Command.Type.SELL, Command.Type.CAST, Command.Type.LEVEL_UP]:
			_add(out, &"ui_error", Vector2.INF, &"ui")
			break
	var me: Entity = world.find_entity(hero_id)
	if me == null:
		return
	var now: Dictionary[int, bool] = {}
	for it: ItemInstance in me.items:
		if it != null:
			now[it.serial] = true
	if _gold >= 0:
		var gained: bool = now.keys().any(func(s: int) -> bool: return not _items.has(s))
		var lost: bool = _items.keys().any(func(s: int) -> bool: return not now.has(s))
		if gained and me.gold < _gold:
			_add(out, &"ui_buy", Vector2.INF, &"ui")
		elif lost and me.gold > _gold:
			_add(out, &"ui_sell", Vector2.INF, &"ui")
	_gold = me.gold
	_items = now


func _remember(world: World, out: Array[Cue]) -> void:
	for e: Entity in world.entities:
		_pos[e.id] = e.position
		_kind[e.id] = e.kind
		_team[e.id] = e.team
		_seen[e.id] = _sees(e)
		if e.kind == Entity.Kind.LANE_CREEP and not _minions:
			_minions = true
			_add(out, &"vo_minions", Vector2.INF, &"vo")


func _sees(e: Entity) -> bool:
	return e.team == team or Rules.is_visible(team, e)


func _kind_of(world: World, id: int) -> int:
	var e: Entity = world.find_entity(id)
	return e.kind if e != null else _kind.get(id, -1)


## Tiếng có vị trí tại đơn vị `id`, chỉ khi đội người chơi thấy nó (VIS: không lộ qua sương mù).
## Đơn vị đã bị gỡ khỏi World (lính vừa chết) dùng vị trí / tầm nhìn của tick trước.
func _seen_add(out: Array[Cue], sid: StringName, id: int) -> Cue:
	var e: Entity = _w.find_entity(id) if _w != null else null
	var seen: bool = _sees(e) if e != null else _seen.get(id, false)
	var at: Vector2 = e.position if e != null else _pos.get(id, Vector2.INF)
	if not seen or not at.is_finite():
		return null
	return _add(out, sid, at, &"sfx")


func _add(out: Array[Cue], sid: StringName, at: Vector2, group: StringName) -> Cue:
	var c: Cue = Cue.new()
	c.id = sid
	c.at = at
	c.group = group
	out.append(c)
	return c
