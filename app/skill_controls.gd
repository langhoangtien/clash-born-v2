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
		buttons.skill_view[i] = [a.rank if a != null else 0, cd, ok, can_level]
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
	var a: AbilityInstance = Abilities.of(hero, SLOTS[i])
	indicator.active = active and a != null and a.rank > 0
	if not indicator.active:
		return
	var v: Dictionary = Abilities.values(hero, a)
	indicator.targeting = a.def.targeting
	indicator.origin = hero.position
	indicator.reach = QuickCast.reach_of(hero, a)
	indicator.area_radius = v.get(&"radius", 0.0)
	indicator.width = v.get(&"width", 0.0)
	indicator.target = hero.position + aim.limit_length(1.0) * indicator.reach


## Phím: 1/2/3 tung vào con trỏ; Ctrl + 1..4 nâng điểm. Trả về true nếu đã xử lý.
## Ô đồ: [tên tắt, giây hồi, số lần dùng, chủ động, dùng được] (ItemButtons).
func _refresh_items() -> void:
	var list: Array[ItemInstance] = Items.slots(hero)
	for i: int in range(Items.SLOTS):
		var it: ItemInstance = list[i]
		if it == null:
			items.item_view[i] = []
			continue
		var a: AbilityInstance = it.ability
		var active: bool = a != null and a.def.targeting != AbilityDef.Targeting.PASSIVE
		var cd: float = maxf(0.0, (a.ready_tick - world.tick) * SimClock.TICK_SECONDS) if a != null else 0.0
		var ok: bool = active and Abilities.problem(world, hero, a) == Abilities.Problem.NONE
		items.item_view[i] = [ItemButtons.short_name(it.def.display_name), cd, it.charges if it.def.charges > 0 else -1, active, ok]
	items.queue_redraw()


func handle_key(key: InputEventKey, cursor: Vector2) -> bool:
	var item_key: int = [KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9].find(key.keycode)
	if item_key >= 0 and not key.ctrl_pressed:
		input.press_skill_at(Items.SLOT_BASE + item_key, cursor)  # ITM-07: phím 4–9
		return true
	var index: int = [KEY_1, KEY_2, KEY_3, KEY_4].find(key.keycode)
	if index < 0:
		return false
	if key.ctrl_pressed:
		level_up(LEVEL_SLOTS[index])
	elif index < SLOTS.size():
		input.press_skill_at(SLOTS[index], cursor)
	return true
