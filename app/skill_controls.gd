class_name SkillControls
extends RefCounted
## Tầng APP (M3.8): nối ô chiêu, nút "+", bảng talent và vạch nhắm với SIM.
## - Ô chiêu: chạm = tung nhanh, kéo = nhắm (AimIndicator), thả vào "Hủy" = thôi.
## - Phím 1/2/3 nhắm vào con trỏ chuột; Ctrl + 1/2/3/4 nâng Q/W/R/thuộc tính (ABL-04).
## - Cấp 20 hiện bảng chọn talent (TAL-01).

const SLOTS: Array[int] = [AbilityDef.Slot.Q, AbilityDef.Slot.W, AbilityDef.Slot.R]
const LEVEL_SLOTS: Array[int] = [AbilityDef.Slot.Q, AbilityDef.Slot.W, AbilityDef.Slot.R, Command.ATTRIBUTES]

var world: World
var hero: Entity
var input: MatchInput
var buttons: SkillButtons
var indicator: AimIndicator
var talents: TalentPanel
var items: ItemButtons


func connect_signals() -> void:
	buttons.skill_tapped.connect(func(i: int) -> void: input.press_skill(SLOTS[i]))
	buttons.skill_aimed.connect(func(i: int, aim: Vector2) -> void: input.press_skill_aimed(SLOTS[i], aim))
	buttons.aim_changed.connect(_on_aim)
	buttons.level_pressed.connect(func(i: int) -> void: level_up(LEVEL_SLOTS[i]))
	talents.chosen.connect(func(slot: int) -> void: world.submit(Command.choose_talent(hero.id, slot)))
	talents.visible = false
	if items != null:
		items.item_tapped.connect(func(i: int) -> void: input.press_skill(Items.SLOT_BASE + i))  # ITM-07
		items.recall_pressed.connect(func() -> void: world.submit(Command.recall(hero.id)))  # RCL-01
		items.item_aimed.connect(func(i: int, aim: Vector2) -> void: input.press_skill_aimed(Items.SLOT_BASE + i, aim))
		items.aim_changed.connect(func(i: int, aim: Vector2, active: bool) -> void: _show_aim(Items.SLOT_BASE + i, aim, active))


func level_up(slot: int) -> void:
	if Progression.level_problem(world, hero, slot) == Command.Reject.NONE:
		world.submit(Command.level_up(hero.id, slot))


## Mỗi khung: trạng thái ô chiêu, nút "+", bảng talent.
func refresh() -> void:
	for i: int in range(SLOTS.size()):
		var a: AbilityInstance = Abilities.of(hero, SLOTS[i])
		var cd: float = maxf(0.0, (a.ready_tick - world.tick) * SimClock.TICK_SECONDS) if a != null else 0.0
		var ok: bool = a != null and Abilities.problem(world, hero, a) == Abilities.Problem.NONE
		var can_level: bool = Progression.level_problem(world, hero, SLOTS[i]) == Command.Reject.NONE
		buttons.skill_view[i] = [a.rank if a != null else 0, cd, ok, can_level, AbilityDef.RANKS[SLOTS[i] as AbilityDef.Slot]]
		buttons.skill_art[i] = a.def.art_id if a != null else &""
	buttons.attributes_can_level = Progression.level_problem(world, hero, Command.ATTRIBUTES) == Command.Reject.NONE
	buttons.queue_redraw()
	var want_talent: bool = hero.talent_slot < 0 and hero.stats.level() >= world.balance.talent_level
	if want_talent and not talents.visible:
		talents.show_options(talent_options())
	elif not want_talent and talents.visible:
		talents.visible = false
	if indicator.active:
		indicator.origin = hero.position
	if items != null:
		_refresh_items()


func talent_options() -> Array:
	var out: Array = []
	for slot: int in SLOTS:
		var a: AbilityInstance = Abilities.of(hero, slot)
		if Progression.talent_problem(world, hero, slot) == Command.Reject.NONE:
			out.append([slot, a.def.talent.display_name, a.def.talent.description])
	return out


func _on_aim(i: int, aim: Vector2, active: bool) -> void:
	_show_aim(SLOTS[i], aim, active)


## Chỉ báo nhắm cho kỹ năng ở ô `slot` (chiêu hoặc đồ); ward: vòng tầm nhìn / nhìn tàng hình tại chỗ cắm.
func _show_aim(slot: int, aim: Vector2, active: bool) -> void:
	var a: AbilityInstance = Abilities.of(hero, slot)
	indicator.active = active and a != null and a.rank > 0
	if not indicator.active:
		return
	var v: Dictionary = Abilities.values(hero, a)
	indicator.targeting = a.def.targeting
	indicator.origin = hero.position
	indicator.reach = QuickCast.reach_of(hero, a)
	indicator.area_radius = v.get(&"radius", 0.0)
	var ward: UnitDef = QuickCast.ward_of(a)
	if ward != null:
		indicator.area_radius = maxf(ward.stats.vision_range, ward.true_sight_range)
	indicator.width = v.get(&"width", 0.0)
	indicator.target = hero.position + aim.limit_length(1.0) * indicator.reach
	indicator.unit_at = Vector2.INF
	if a.def.targeting == AbilityDef.Targeting.UNIT and a.def.target_team == AbilityDef.Team.ENEMY:
		var t: Entity = QuickCast.unit_for_aim(world, hero, a, aim)  # D-108: tô đỏ kẻ sẽ bị chọn
		if t != null:
			indicator.unit_at = t.position
			indicator.unit_radius = t.radius


## Phím: 1/2/3 tung vào con trỏ; Ctrl + 1..4 nâng điểm. Trả về true nếu đã xử lý.
## D-87: chỉ món chủ động có nút, theo thứ tự ô: [ô, tên tắt, giây hồi, số lần dùng, dùng được].
func _refresh_items() -> void:
	var view: Array = []
	for it: ItemInstance in Items.slots(hero):
		if it == null or it.ability == null or it.def.ability.targeting == AbilityDef.Targeting.PASSIVE:
			continue
		var a: AbilityInstance = it.ability
		var cd: float = maxf(0.0, (a.ready_tick - world.tick) * SimClock.TICK_SECONDS)
		var ok: bool = Abilities.problem(world, hero, a) == Abilities.Problem.NONE
		view.append([it.index, ItemButtons.short_name(it.def.display_name), cd, it.charges if it.def.charges > 0 else -1, ok, it.def.art_id])
	items.item_view = view
	var total: int = SimClock.seconds_to_ticks(world.balance.recall_time)
	items.recall_progress = clampf(float(world.tick - hero.recall_start_tick) / maxf(1.0, total), 0.0, 1.0) if hero.recall_until_tick >= 0 else -1.0
	items.queue_redraw()


func handle_key(key: InputEventKey, cursor: Vector2) -> bool:
	if key.keycode == KEY_H and not key.ctrl_pressed:
		world.submit(Command.recall(hero.id))  # RCL-01
		return true
	var item_key: int = [KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9].find(key.keycode)
	if item_key >= 0 and not key.ctrl_pressed and items != null:
		var slot: int = items.slot_for_button(item_key)  # D-89: phím 4..9 = nút đồ chủ động thứ 1..6
		if slot >= 0:
			input.press_skill_at(Items.SLOT_BASE + slot, cursor)
		return true
	var index: int = [KEY_1, KEY_2, KEY_3, KEY_4].find(key.keycode)
	if index < 0:
		return false
	if key.ctrl_pressed:
		level_up(LEVEL_SLOTS[index])
	elif index < SLOTS.size():
		input.press_skill_at(SLOTS[index], cursor)
	return true
