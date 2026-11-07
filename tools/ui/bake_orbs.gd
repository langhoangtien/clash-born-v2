extends SceneTree
## D-290: dựng sẵn ảnh nút tròn (UiBake.RADII) thành PNG trong UiBake.BAKED_DIR — game nạp ảnh, khỏi tính từng
## điểm ảnh lúc vào trận. Chạy lại khi đổi hình nút (UiBake) hoặc thêm bán kính, rồi import:
##   godot --headless --path . -s tools/ui/bake_orbs.gd && godot --headless --path . --import


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UiBake.BAKED_DIR))
	for r: float in UiBake.RADII:
		var path: String = UiBake.baked_path(r)
		UiBake.orb_image(r).save_png(ProjectSettings.globalize_path(path))
		print(path)
	quit(0)
