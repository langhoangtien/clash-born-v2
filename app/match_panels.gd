class_name MatchPanels
extends RefCounted
## Màn trận (tách khỏi match_scene.gd — _ready quá 40 dòng): nối điều khiển chiêu (SkillControls), hàng nút đồ, bảng shop
## (D-81, D-115, D-120: bộ đồ soạn sẵn) và bảng thông số (D-253) với World / hero của màn. Không đổi hành vi.


## `scene`: màn trận (app/match_scene.gd) đã có world, hero, input, skills và các nút HUD.
static func attach(scene: Node) -> void:
	var hud: Node = scene.get_node("Hud")
	var world: World = scene.world
	var hero: Entity = scene.hero
	var skills: SkillControls = scene.skills
	skills.world = world
	skills.hero = hero
	skills.input = scene.input
	skills.buttons = scene.skill_buttons
	skills.indicator = scene.aim_indicator
	skills.talents = scene.talent_panel
	var item_buttons: ItemButtons = ItemButtons.new()
	item_buttons.name = "ItemButtons"
	hud.add_child(item_buttons)
	item_buttons.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skills.items = item_buttons
	scene.shop = _shop(scene, hud, world, hero)
	_info(hud, world, hero, skills)


static func _shop(scene: Node, hud: Node, world: World, hero: Entity) -> ShopPanel:
	var shop: ShopPanel = ShopPanel.new()
	shop.name = "ShopPanel"
	hud.add_child(shop)
	shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop.world = world
	shop.z_index = 10  # D-115: bảng shop / tỷ số vẽ trên cụm nút điều khiển
	shop.hero = hero
	var hero_id: StringName = hero.hero_def.id
	shop.buy_pressed.connect(func(id: StringName) -> void: world.submit(Command.buy(hero.id, id)))  # SHOP-01
	shop.sell_pressed.connect(func(i: int) -> void: world.submit(Command.sell(hero.id, i)))  # SHOP-05
	shop.build = BuildPresets.load_build(hero_id)  # D-120: bộ đồ soạn sẵn của tướng này
	shop.build_changed.connect(func(b: Array[StringName]) -> void:
		var done: Array[StringName] = scene._build_done
		BuildPresets.save_build(hero_id, done + b))
	return shop


static func _info(hud: Node, world: World, hero: Entity, skills: SkillControls) -> void:
	var info: InfoPanels = InfoPanels.new()
	info.name = "InfoPanels"
	hud.add_child(info)
	info.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info.world = world
	info.z_index = 10
	info.hero = hero
	info.level_pressed.connect(skills.level_up)  # D-253: nâng chiêu / chọn talent ngay trong bảng thông số
	info.talent_pressed.connect(func(slot: int) -> void: world.submit(Command.choose_talent(hero.id, slot)))
