extends TestCase
## D-300 (lỗi người chơi tìm ra): lên thẳng cấp 20 (bảng thử) khi chưa cộng chiêu → bảng talent dựng một lần, rỗng; cộng
## chiêu sau đó cũng không hiện lựa chọn. Bảng phải cập nhật khi các lựa chọn đổi.

const SCENE: String = "res://app/match_scene.tscn"


func test_D_300_talent_options_refresh_after_leveling_skills() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	scene.set_process(false)
	var w: World = scene.world
	var h: Entity = scene.hero
	var skills: SkillControls = scene.skills
	for slot: int in [AbilityDef.Slot.Q, AbilityDef.Slot.W, AbilityDef.Slot.R]:
		Abilities.set_rank(w, h, Abilities.of(h, slot), 0)
	Progression.add_xp(w, h, 100000.0)
	skills.refresh()
	var panel: TalentPanel = scene.talent_panel
	assert_true(panel.visible, "cấp 20 chưa chọn talent: bảng hiện")
	assert_eq(panel.find_children("Talent*", "Button", true, false).size(), 0, "chưa chiêu nào có cấp: chưa có lựa chọn")
	Abilities.set_rank(w, h, Abilities.of(h, AbilityDef.Slot.Q), 1)
	skills.refresh()
	var names: Array = panel.find_children("Talent*", "Button", true, false).filter(func(b: Node) -> bool: return not b.is_queued_for_deletion()).map(func(b: Node) -> String: return b.name)
	assert_eq(names, ["Talent1"], "cộng Q xong: hiện talent Q")
	scene.queue_free()
