extends SceneTree
## D-331: xuất danh sách đồ (id, tên, giá, icon) cho trang Clashborn Stats → JSON ở đường dẫn tham số.
## godot --headless --path . -s tools/site/export_items.gd -- <out.json>


func _initialize() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var out: Array = []
	for id: StringName in lib.items:
		var it: ItemDef = lib.items[id]
		out.append({"id": String(id), "name": it.display_name, "cost": it.cost, "icon": String(it.art_id)})
	var f: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	quit(0)
