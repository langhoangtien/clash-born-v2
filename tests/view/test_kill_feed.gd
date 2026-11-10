extends TestCase
## D-339 (EVT hero_died): thông báo hạ gục — ai hạ ai, bị trụ hạ, hạ gục đầu tiên, chuỗi hạ liên tiếp.

const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"


func _setup() -> Array:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	var a: Entity = UnitFactory.hero(w, lib.heroes[&"gorran"], 0, Vector2(1000, 1000))
	var foes: Array[Entity] = []
	for id: StringName in [&"myra", &"vexa", &"noctis"]:
		foes.append(UnitFactory.hero(w, lib.heroes[id], 1, Vector2(1200, 1000)))
	var tower: Entity = UnitFactory.unit(w, lib.units[&"tower_t1"], Entity.Kind.TOWER, 1, Vector2(1500, 1500))
	var feed: KillFeed = KillFeed.new()
	feed.world = w
	return [w, a, foes, tower, feed]


func test_D_339_kill_lines_first_blood_and_streak() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var feed: KillFeed = s[4]
	var lines: Array[String] = []
	var tags: Array[String] = []
	for k: int in 3:
		s[2][k].killer_id = s[1].id
		w.tick += 30 * 3
		feed.add_kill(s[2][k])
		lines.append(KillFeed.line_of(feed.rows()[-1]))
		tags.append(feed.rows()[-1]["tag"])
	assert_eq(lines, ["Gorran hạ Myra", "Gorran hạ Vexa", "Gorran hạ Noctis"] as Array[String])
	assert_eq(tags, ["Hạ gục đầu tiên", "Hạ đôi", "Hạ ba"] as Array[String])
	s[1].killer_id = s[3].id
	w.tick += 30 * 20
	feed.add_kill(s[1])
	assert_eq(KillFeed.line_of(feed.rows()[-1]), "Gorran bị trụ hạ")
	assert_eq(feed.rows().size(), KillFeed.MAX_ROWS, "tối đa MAX_ROWS dòng (D-341: 2)")
	s[2][0].killer_id = s[1].id
	w.tick += 30 * 20
	feed.add_kill(s[2][0])
	assert_eq(feed.rows()[-1]["tag"], "", "quá 10 giây: hết chuỗi, không còn hạ gục đầu tiên")
	feed.free()


func test_D_341_feed_shows_killer_gold_from_events() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var feed: KillFeed = s[4]
	var victim: Entity = s[2][0]
	victim.killer_id = s[1].id
	var events: Array[GameEvent] = [GameEvent.make(&"kill_credited", 1, s[1].id, victim.id, 360),
		GameEvent.make(&"hero_died", 1, -1, victim.id)]
	feed._scan(events)
	assert_eq(feed.rows()[0]["gold"], 360, "vàng kẻ hạ (kill_credited) hiện trên băng")
	s[1].killer_id = s[3].id
	feed._scan([GameEvent.make(&"kill_credited", 2, s[2][1].id, s[1].id, 200), GameEvent.make(&"hero_died", 2, -1, s[1].id)] as Array[GameEvent])
	assert_eq(feed.rows()[1]["gold"], 0, "trụ hạ: vàng chia cho cả đội, không hiện")
	feed.free()
