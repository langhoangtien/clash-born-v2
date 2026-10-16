extends TestCase
## M5.6 (D-77): ký hiệu map dev — tên duy nhất, cặp đối xứng, lưới ô cờ.

const MAP_PATH: String = "res://data/maps/clashborn.tres"


func _layout() -> MapLayout:
	return load(MAP_PATH) as MapLayout


func test_D_77_grid_cell_names() -> void:
	var m: MapLayout = _layout()
	assert_eq(MapLabels.cell_name(m, Vector2(1, 1)), "A1")
	assert_eq(MapLabels.cell_name(m, m.world_size() - Vector2(1, 1)), "P16")
	assert_eq(MapLabels.cell_name(m, m.world_size() * 0.5), "I9")
	assert_eq(MapLabels.cell_name(m, Vector2(-50, 99999)), "A16", "ngoài map thì kẹp vào mép")


func test_D_77_tower_and_camp_names() -> void:
	assert_eq(MapLabels.tower_name("blue_top_t1"), "X-TOP-1")
	assert_eq(MapLabels.tower_name("red_bot_t3"), "Đ-BOT-3")
	assert_eq(MapLabels.tower_name("blue_base_guard_left"), "X-NHÀ-T")
	assert_eq(MapLabels.tower_name("red_base_guard_right"), "Đ-NHÀ-P")
	assert_eq(MapLabels.camp_name("camp_blue_03"), "TX3")
	assert_eq(MapLabels.camp_name("camp_red_06"), "TĐ6")
	assert_eq(MapLabels.camp_name("boss_pit"), "BOSS")


func test_D_77_all_names_unique_and_mirrored() -> void:
	var m: MapLayout = _layout()
	var marks: Array[MapLabels.Mark] = MapLabels.build(m)
	var seen: Dictionary = {}
	var at: Dictionary = {}
	for k: MapLabels.Mark in marks:
		assert_false(seen.has(k.text), "tên trùng: " + k.text)
		seen[k.text] = true
		at[k.text] = k.position
	for i: int in range(1, 8):
		assert_true(seen.has("B%d" % i) and seen.has("B%d'" % i), "bụi B%d có cặp" % i)
	for name: String in ["K1", "K2", "K1'", "K2'", "X-TOP-1", "Đ-MID-3", "TX6", "TĐ6", "BOSS"]:
		assert_true(seen.has(name), name)
	var pairs: int = 0
	for name: String in at:
		if name.ends_with("'"):
			var base: String = name.trim_suffix("'")
			assert_true(at.has(base), "%s có bản xanh %s" % [name, base])
			if at.has(base):
				pairs += 1
				assert_true((m.world_size() - at[name]).distance_to(at[base]) < 300.0, "%s đối xứng với %s" % [name, base])
	var forests: int = marks.filter(func(k: MapLabels.Mark) -> bool: return k.kind == MapLabels.Kind.FOREST).size()
	assert_true(forests >= 10, "đặt tên các khối rừng lớn (%d)" % forests)
	assert_true(pairs > 20)
