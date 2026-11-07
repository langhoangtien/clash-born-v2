extends SceneTree
## D-284: xuất danh sách tướng chơi được cho trang giới thiệu (tên, hệ, 4 chiêu kèm icon) → JSON ở đường dẫn tham số.
## godot --headless --path . -s tools/site/export_heroes.gd -- <out.json>

const PLAYABLE: Array[StringName] = [&"brakk", &"myra", &"noctis", &"vexa", &"gorran", &"duy_anh"]
const ATTR: Array[String] = ["", "Sức mạnh", "Nhanh nhẹn", "Trí tuệ"]  # theo StatFormulas.Attribute


func _initialize() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var out: Array = []
	for id: StringName in PLAYABLE:
		var h: HeroDef = lib.heroes[id]
		var skills: Array = []
		for a: AbilityDef in [h.innate, h.q, h.w, h.r]:
			if a != null:
				skills.append({"slot": ["Nội tại", "Q", "W", "R"][[h.innate, h.q, h.w, h.r].find(a)],
					"name": a.display_name, "text": a.description, "icon": String(a.art_id)})
		out.append({"id": String(id), "name": h.display_name, "attribute": ATTR[int(h.primary_attribute)], "skills": skills})
	var f: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	quit(0)
