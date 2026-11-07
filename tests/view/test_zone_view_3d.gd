extends TestCase
## D-297: vùng kỹ năng vẽ 3D — vũng (vùng tồn tại) / vùng nạp (vùng có độ trễ), màu theo mảnh `zone` / `pending` của
## kỹ năng sinh ra vùng (tìm trong cây hành động của kỹ năng), không có thì màu phe; vùng hết thì gỡ.

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")


## Hành động kiểu `type` đầu tiên trong cây on_cast của kỹ năng.
func _find(list: Array, type: Variant) -> ActionDef:
	for a: Variant in list:
		if is_instance_of(a, type):
			return a
		if a is Resource:
			for prop: Dictionary in (a as Resource).get_property_list():
				var v: Variant = (a as Resource).get(prop["name"])
				if v is Array:
					var got: ActionDef = _find(v, type)
					if got != null:
						return got
	return null


func test_D_297_zone_color_from_recipe_and_cleanup() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, Fixture.make())
	var gorran: Entity = UnitFactory.hero(w, lib.heroes[&"gorran"], 0, Vector2(500, 500))
	var z: ActiveZone = ActiveZone.new()
	z.action = _find(Abilities.of(gorran, AbilityDef.Slot.Q).def.on_cast, ZoneAction)
	assert_true(z.action != null, "Vũng Axit có ZoneAction")
	z.source_id = gorran.id
	z.center = Vector2(800, 600)
	z.radius = 250.0
	z.start_tick = 0
	z.end_tick = 90
	z.interval_ticks = 15
	w.zones.append(z)
	assert_eq(ZoneView3D.part_for(w, "zone", z.action, z.source_id, 0).get("color"), "#8fbf3a", "màu axit của Gorran Q")
	var v: ZoneView3D = ZoneView3D.new()
	v.sync(w)
	assert_eq(v.count(), 1)
	assert_near((v.get_child(0) as Node3D).position.x, 800 * MatchView3D.S, 0.001)
	w.zones.clear()
	v.sync(w)
	assert_eq(v.count(), 0, "vùng hết: gỡ")
	v.free()


func test_D_297_unknown_zone_uses_team_color() -> void:
	var w: World = World.new(1, Fixture.make())
	var part: Dictionary = ZoneView3D.part_for(w, "pending", ZoneAction.new(), 999, 1)
	assert_eq(part["type"], "pending")
	assert_true(String(part["color"]).length() == 7, "màu phe")
