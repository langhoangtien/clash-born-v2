extends RefCounted
## Dữ liệu mẫu chỉ dùng trong test (ARCHITECTURE mục 9): một hero thử nghiệm hợp lệ có
## đủ nội tại bash (nhóm duy nhất), Q vùng choáng, W khiên, R ghost + talent, và một
## món đồ. Test sửa từng chỗ để kiểm tra validator bắt đúng lỗi.


static func stun() -> EffectDef:
	var e: EffectDef = EffectDef.new()
	e.id = &"test_stun"
	e.states = [UnitState.Id.STUNNED]
	e.tags = [&"debuff"]
	e.dispel = EffectDef.Dispel.STRONG
	return e


static func ability(id: StringName, slot: AbilityDef.Slot, names: PackedStringArray) -> AbilityDef:
	var a: AbilityDef = AbilityDef.new()
	a.id = id
	a.slot = slot
	var ranks: int = AbilityDef.RANKS[slot]
	for n: String in names:
		var row: PackedFloat32Array = PackedFloat32Array()
		for i: int in range(ranks):
			row.append(10.0 * (i + 1))
		a.values[StringName(n)] = row
	return a


static func innate() -> AbilityDef:
	var a: AbilityDef = ability(&"test_bash", AbilityDef.Slot.INNATE, ["chance", "bonus_damage", "stun_duration"])
	a.targeting = AbilityDef.Targeting.PASSIVE
	var dmg: DamageAction = DamageAction.new()
	dmg.target = ActionDef.Target.EVENT_TARGET
	dmg.amount = "bonus_damage"
	var apply_stun: ApplyEffectAction = ApplyEffectAction.new()
	apply_stun.target = ActionDef.Target.EVENT_TARGET
	apply_stun.effect = stun()
	apply_stun.duration = "stun_duration"
	var trig: TriggerDef = TriggerDef.new()
	trig.event = &"attack_landed"
	trig.role = TriggerDef.Role.SOURCE
	trig.chance = "chance"
	trig.condition = &"target_not_structure"
	trig.unique_group = &"bash"
	trig.actions = [dmg, apply_stun]
	var passive: EffectDef = EffectDef.new()
	passive.id = &"test_bash_passive"
	passive.duration = "0"
	passive.tags = [&"passive"]
	passive.dispel = EffectDef.Dispel.NONE
	passive.triggers = [trig]
	var learn: ApplyEffectAction = ApplyEffectAction.new()
	learn.target = ActionDef.Target.SELF
	learn.effect = passive
	a.on_learn = [learn]
	return a


static func q() -> AbilityDef:
	var a: AbilityDef = ability(&"test_slam", AbilityDef.Slot.Q, ["damage", "stun_duration", "radius", "cooldown", "mana"])
	var hit: DamageAction = DamageAction.new()
	hit.amount = "damage"
	var apply_stun: ApplyEffectAction = ApplyEffectAction.new()
	apply_stun.effect = stun()
	apply_stun.duration = "stun_duration"
	var area: AreaAction = AreaAction.new()
	area.target = ActionDef.Target.SELF
	area.radius = "radius"
	area.actions = [hit, apply_stun]
	a.on_cast = [area]
	a.talent = talent(&"test_slam_ii", &"radius")
	a.bot_usages = [AbilityDef.BotUsage.DISABLE]
	return a


static func w() -> AbilityDef:
	var a: AbilityDef = ability(&"test_shield", AbilityDef.Slot.W, ["shield", "duration", "cooldown", "mana"])
	a.target_team = AbilityDef.Team.SELF
	var shield: EffectDef = EffectDef.new()
	shield.id = &"test_shield_effect"
	shield.absorb = "shield"
	shield.duration = "duration"
	shield.tags = [&"buff"]
	var apply: ApplyEffectAction = ApplyEffectAction.new()
	apply.target = ActionDef.Target.SELF
	apply.effect = shield
	a.on_cast = [apply]
	a.talent = talent(&"test_shield_ii", &"shield")
	return a


static func r() -> AbilityDef:
	var a: AbilityDef = ability(&"test_ghost", AbilityDef.Slot.R, ["duration", "heal_percent", "move_bonus", "cooldown", "mana"])
	a.target_team = AbilityDef.Team.SELF
	var speed: ModifierDef = ModifierDef.new()
	speed.stat = &"movement_speed"
	speed.op = ModifierDef.Op.MULTIPLY
	speed.value = "1 + move_bonus / 100"
	var heal: HealAction = HealAction.new()
	heal.target = ActionDef.Target.SELF
	heal.amount = "self.max_hp * heal_percent / 100 / duration * 0.5"
	var ghost: EffectDef = EffectDef.new()
	ghost.id = &"test_ghost_effect"
	ghost.duration = "duration"
	ghost.states = [UnitState.Id.GHOST]
	ghost.modifiers = [speed]
	ghost.periodic_interval = "0.5"
	ghost.periodic_actions = [heal]
	ghost.dispel = EffectDef.Dispel.NONE
	var apply: ApplyEffectAction = ApplyEffectAction.new()
	apply.target = ActionDef.Target.SELF
	apply.effect = ghost
	a.on_cast = [apply]
	a.talent = talent(&"test_ghost_ii", &"duration")
	return a


static func talent(id: StringName, value_name: StringName) -> TalentDef:
	var t: TalentDef = TalentDef.new()
	t.id = id
	var change: ValueChangeDef = ValueChangeDef.new()
	change.value_name = value_name
	change.amount = 1.0
	t.value_changes = [change]
	return t


static func hero() -> HeroDef:
	var h: HeroDef = HeroDef.new()
	h.id = &"test_brute"
	h.display_name = "Hero thử nghiệm"
	h.base_strength = 25
	h.strength_growth = 3.0
	var s: CombatStatsDef = CombatStatsDef.new()
	s.base_hp = 200
	s.base_damage = 50
	s.base_attack_time = 1.7
	s.attack_point = 0.4
	s.attack_range = 150
	s.movement_speed = 300
	s.collision_radius = 32
	h.stats = s
	h.innate = innate()
	h.q = q()
	h.w = w()
	h.r = r()
	h.bot_skill_order = [HeroDef.Upgrade.Q, HeroDef.Upgrade.W, HeroDef.Upgrade.Q]
	h.bot_talent_priority = [AbilityDef.Slot.Q, AbilityDef.Slot.R, AbilityDef.Slot.W]
	return h


static func item() -> ItemDef:
	var i: ItemDef = ItemDef.new()
	i.id = &"test_hammer"
	i.cost = 2900
	var dmg: ModifierDef = ModifierDef.new()
	dmg.stat = &"physical_damage"
	dmg.value = "25"
	i.modifiers = [dmg]
	return i


static func library_with(defs: Array[GameDef]) -> ContentLibrary:
	var lib: ContentLibrary = ContentLibrary.new()
	for d: GameDef in defs:
		lib._add("fixture://" + String(d.id), d)
	return lib
