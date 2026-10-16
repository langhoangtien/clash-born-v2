class_name Abilities
extends RefCounted
## Kỹ năng trên đơn vị: dựng từ HeroDef, giá trị theo cấp (ABL-09, ITM-05), học/lên cấp
## (bị động áp lại hiệu ứng on_learn), kiểm tra dùng được (ABL-02).

## Lý do không dùng được (khớp Command.Reject).
enum Problem { NONE, NOT_LEARNED, ON_COOLDOWN, NO_MANA, CANNOT_CAST, BAD_TARGET }


static func setup_hero(world: World, e: Entity, def: HeroDef) -> void:
	for pair: Array in [[AbilityDef.Slot.INNATE, def.innate], [AbilityDef.Slot.Q, def.q], [AbilityDef.Slot.W, def.w], [AbilityDef.Slot.R, def.r]]:
		if pair[1] == null:
			continue
		var a: AbilityInstance = AbilityInstance.new()
		a.def = pair[1]
		a.slot = pair[0]
		e.abilities.append(a)
	var innate: AbilityInstance = of(e, AbilityDef.Slot.INNATE)
	if innate != null:
		set_rank(world, e, innate, 1)  # ABL-11: nội tại có từ cấp 1


static func of(e: Entity, slot: int) -> AbilityInstance:
	if slot >= Items.SLOT_BASE:
		return Items.ability_at(e, slot)  # ITM-07
	for a: AbilityInstance in e.abilities:
		if a.slot == slot:
			return a
	return null


## Giá trị có tên ở cấp hiện tại; tên gốc `x` lấy `x_melee` / `x_ranged` theo đơn vị (ITM-05).
static func values(e: Entity, a: AbilityInstance) -> Dictionary:
	var out: Dictionary = {}
	var index: int = clampi(a.rank - 1, 0, a.def.expected_ranks() - 1)
	for key: StringName in a.def.values:
		var arr: PackedFloat32Array = a.def.values[key]
		out[key] = float(arr[mini(index, arr.size() - 1)]) if arr.size() > 0 else 0.0
	if a.talent_active:  # TAL-02a
		for change: ValueChangeDef in a.def.talent.value_changes:
			var v: float = out.get(change.value_name, 0.0)
			match change.op:
				ValueChangeDef.Op.ADD:
					out[change.value_name] = v + change.amount
				ValueChangeDef.Op.MULTIPLY:
					out[change.value_name] = v * change.amount
				ValueChangeDef.Op.SET:
					out[change.value_name] = change.amount
	var suffix: String = "_melee" if e.projectile_speed <= 0.0 else "_ranged"
	for key: StringName in out.keys():
		if String(key).ends_with(suffix):
			out[StringName(String(key).trim_suffix(suffix))] = out[key]
	return out


static func value(e: Entity, a: AbilityInstance, name: StringName) -> float:
	return values(e, a).get(name, 0.0)


## Học / lên cấp: hiệu ứng bị động cũ gỡ, chạy lại on_learn với giá trị cấp mới.
static func set_rank(world: World, e: Entity, a: AbilityInstance, rank: int) -> void:
	a.rank = rank
	for inst: EffectInstance in a.learned_effects:
		Effects.remove(world, e, inst, &"removed")
	a.learned_effects.clear()
	if rank <= 0 or a.def.on_learn.is_empty():
		return
	var before: Array[EffectInstance] = e.effects.duplicate()
	ActionRunner.run(world, a.def.on_learn, context(e, a, e), e.id)
	for inst: EffectInstance in e.effects:
		if not before.has(inst):
			a.learned_effects.append(inst)


static func context(e: Entity, a: AbilityInstance, target: Entity) -> ExprContext:
	var ctx: ExprContext = ExprContext.make(e, target, values(e, a))
	ctx.ability = a.def
	ctx.item_slot = a.item_index + 1
	return ctx


## ABL-02: dùng được ngay bây giờ chưa (không xét tầm).
static func problem(world: World, e: Entity, a: AbilityInstance) -> Problem:
	if a == null or a.rank <= 0:
		return Problem.NOT_LEARNED
	if a.def.targeting == AbilityDef.Targeting.PASSIVE or not (Rules.can_use_item(e) if a.item_index >= 0 else Rules.can_cast(e)):
		return Problem.CANNOT_CAST
	if world.tick < a.ready_tick:
		return Problem.ON_COOLDOWN
	if e.mana < value(e, a, &"mana"):
		return Problem.NO_MANA
	return Problem.NONE


## ABL-07 / target_filter: đơn vị `t` có phải đối tượng hợp lệ của kỹ năng do `caster` dùng.
## `need_sight` = false cho vùng và đạn kỹ năng: trúng cả kẻ không thấy (ABL-07, VIS-05).
static func accepts(caster: Entity, def: AbilityDef, t: Entity, need_sight: bool = true) -> bool:
	if t == null or not t.alive or t.kind == Entity.Kind.WARD:
		return false  # WRD-04: chiêu không nhắm / không trúng ward
	var as_enemy: bool = def.target_team == AbilityDef.Team.ENEMY or (def.target_team == AbilityDef.Team.ANY and t.team != caster.team)
	if as_enemy:
		if not (Rules.is_targetable(caster, t) if need_sight else Rules.is_hittable(caster, t)):
			return false
		if need_sight and not def.pierces_magic_immunity and Rules.has_state(t, UnitState.Id.MAGIC_IMMUNE):
			return false  # ST-15: chiêu nhắm đơn vị không chọn được (kể cả chiêu "bất kỳ" khi nhắm địch)
	match def.target_team:
		AbilityDef.Team.ALLY:
			if t.team != caster.team:
				return false
		AbilityDef.Team.SELF:
			return t == caster
	match t.kind:
		Entity.Kind.HERO:
			return def.hits_heroes
		Entity.Kind.LANE_CREEP:
			return def.hits_creeps
		Entity.Kind.NEUTRAL:
			return def.hits_neutrals
	return def.hits_structures


## TAL-02c: hiệu ứng `def` do `source` áp, đã vá theo talent đã chọn (thêm trigger/modifier).
static func patched(source: Entity, def: EffectDef) -> EffectDef:
	if source == null or source.talent_slot < 0:
		return def
	var a: AbilityInstance = of(source, source.talent_slot)
	if a == null or not a.talent_active:
		return def
	if a.patched.has(def):
		return a.patched[def]
	for patch: EffectPatchDef in a.def.talent.effect_patches:
		if patch.effect == def:
			var copy: EffectDef = def.duplicate(false)
			copy.triggers = def.triggers + patch.add_triggers
			copy.modifiers = def.modifiers + patch.add_modifiers
			a.patched[def] = copy
			return copy
	return def


## Hành động khi tung: on_cast, nối thêm hành động của talent (TAL-02b).
static func cast_actions(a: AbilityInstance) -> Array[ActionDef]:
	if a.talent_active and not a.def.talent.extra_actions.is_empty():
		return a.def.on_cast + a.def.talent.extra_actions
	return a.def.on_cast
