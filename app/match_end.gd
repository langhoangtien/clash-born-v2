class_name MatchEnd
extends RefCounted
## Kết thúc trận ở màn trận (tách khỏi match_scene.gd): bảng kết quả, ghi thống kê (ST.1, D-339; online: máy chủ phòng ghi —
## NET-12, D-405), nút Chơi lại / Về menu.


## Hiện bảng kết quả trên lớp `hud`; `online` != null → trận online (Chơi lại = về menu, máy khách không gửi biên bản).
static func show(hud: Node, world: World, hero: Entity, config: MatchConfig, online: OnlineSession, menu: String) -> ResultPanel:
	var result: ResultPanel = ResultPanel.new()
	hud.add_child(result)
	result.show_result(world, hero)
	var tree: SceneTree = hud.get_tree()
	# ST.1, D-339; D-341: gắn vào gốc cây — bấm về menu ngay không hủy yêu cầu gửi
	if online != null:
		result.set_stats_note("Thống kê: máy chủ phòng ghi trận online", false)  # NET-12 (ST.5, D-405)
	elif not MatchUpload.send(tree.root, MatchRecord.of(world, config, Updater.current_name()), result.set_stats_note):
		result.set_stats_note("Thống kê: trận thử / đo hiệu năng — không tính", false)
	result.replay_pressed.connect(func() -> void:
		tree.change_scene_to_file(menu) if online != null else tree.reload_current_scene())
	result.menu_pressed.connect(func() -> void: tree.change_scene_to_file(menu))
	return result
