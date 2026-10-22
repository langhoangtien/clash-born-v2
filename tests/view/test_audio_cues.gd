extends TestCase
## D-114: sự kiện SIM → tiếng cần phát (AudioCues).


func _setup() -> Array:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	var me: Entity = UnitFactory.hero(w, lib.heroes[&"brakk"], 0, Vector2(1000, 1000))
	var foe: Entity = UnitFactory.hero(w, lib.heroes[&"myra"], 1, Vector2(1200, 1000))
	var cues: AudioCues = AudioCues.new()
	cues.team = 0
	cues.hero_id = me.id
	cues.collect(w)  # tick đầu: welcome
	return [w, me, foe, cues]


func _ids(list: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for c: AudioCues.Cue in list:
		out.append(c.id)
	return out


func _run(w: World, cues: AudioCues, events: Array[GameEvent]) -> Array[StringName]:
	w.events.clear()
	w.events.append_array(events)
	return _ids(cues.collect(w))


func test_D_114_first_tick_welcome_announcement() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	UnitFactory.hero(w, lib.heroes[&"brakk"], 0, Vector2(1000, 1000))
	var cues: AudioCues = AudioCues.new()
	assert_true(_ids(cues.collect(w)).has(&"vo_welcome"))
	assert_false(_ids(cues.collect(w)).has(&"vo_welcome"), "chỉ một lần")


func test_D_114_hero_hit_sound_by_attacker_kind() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var me: Entity = s[1]
	var foe: Entity = s[2]
	var cues: AudioCues = s[3]
	assert_true(_run(w, cues, [GameEvent.make(&"attack_landed", 1, me.id, foe.id, 50)]).has(&"hit_melee"), "Brakk đánh gần, sức mạnh")
	assert_true(_run(w, cues, [GameEvent.make(&"attack_landed", 1, foe.id, me.id, 50)]).has(&"hit_magic"), "Myra đánh xa")
	assert_true(_run(w, cues, [GameEvent.make(&"attack_landed", 1, me.id, foe.id, 50, &"crit")]).has(&"hit_crit"))
	assert_true(_run(w, cues, [GameEvent.make(&"attack_started", 1, foe.id, me.id)]).has(&"shot_magic"))


func test_D_114_no_sound_from_units_hidden_in_fog() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var me: Entity = s[1]
	var foe: Entity = s[2]
	var cues: AudioCues = s[3]
	foe.visible_mask = 1 << 1  # chỉ đội của nó thấy
	var cast: GameEvent = GameEvent.make(&"ability_cast", 1, foe.id, -1, AbilityDef.Slot.Q)
	assert_false(_run(w, cues, [cast]).has(&"cast_myra_q"), "địch trong sương: không phát")
	foe.visible_mask = -1
	assert_true(_run(w, cues, [cast]).has(&"cast_myra_q"), "thấy địch: phát tiếng chiêu theo id kỹ năng")
	assert_true(_run(w, cues, [GameEvent.make(&"ability_cast", 1, me.id, -1, AbilityDef.Slot.W)]).has(&"cast_brakk_w"))


func test_D_114_last_hit_on_removed_creep_uses_last_position() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var me: Entity = s[1]
	var cues: AudioCues = s[3]
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var creep: Entity = UnitFactory.unit(w, lib.units.values().filter(func(d: UnitDef) -> bool: return d.kind == UnitDef.Kind.CREEP_MELEE)[0], Entity.Kind.LANE_CREEP, 1, Vector2(1100, 1000))
	var first: Array[StringName] = _run(w, cues, [])
	assert_true(first.has(&"vo_minions"), "lần đầu thấy lính ra đường")
	w.remove_entity(creep)
	var ids: Array[StringName] = _run(w, cues, [GameEvent.make(&"unit_died", 1, me.id, creep.id)])
	assert_true(ids.has(&"creep_death"))
	assert_true(ids.has(&"ui_gold"), "last hit của người chơi: tiếng xu vàng")


func test_D_112_first_blood_spree_and_shut_down() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var me: Entity = s[1]
	var foe: Entity = s[2]
	var cues: AudioCues = s[3]
	var kill: Callable = func(k: Entity, v: Entity) -> Array[StringName]:
		return _run(w, cues, [GameEvent.make(&"kill_credited", 1, k.id, v.id, 200), GameEvent.make(&"hero_died", 1, -1, v.id)])
	assert_true(kill.call(me, foe).has(&"vo_first_blood"))
	assert_false(kill.call(me, foe).has(&"vo_killing_spree"), "2 mạng: chưa có thông báo")
	assert_true(kill.call(me, foe).has(&"vo_killing_spree"), "3 mạng liên tiếp")
	assert_true(kill.call(me, foe).has(&"vo_dominating"))
	var back: Array[StringName] = kill.call(foe, me)
	assert_true(back.has(&"vo_shut_down"), "hạ kẻ đang chuỗi ≥ 3")
	assert_true(back.has(&"hero_death"))


func test_D_114_buy_sell_and_rejected_command_sounds() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var me: Entity = s[1]
	var cues: AudioCues = s[3]
	var lib: ContentLibrary = ContentLibrary.load_dir()
	me.gold = 1000
	_run(w, cues, [])
	Items.give(w, me, lib.items[&"circlet"])
	me.gold = 850
	assert_true(_run(w, cues, []).has(&"ui_buy"))
	me.items.clear()
	me.gold = 925
	assert_true(_run(w, cues, []).has(&"ui_sell"))
	var bad: Command = Command.buy(me.id, &"divine_blade")
	bad.reject_reason = Command.Reject.UNIT_DEAD
	w.rejected_commands.append(bad)
	assert_true(_run(w, cues, []).has(&"ui_error"))
	w.rejected_commands.clear()


func test_D_114_recall_loop_starts_and_stops() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var me: Entity = s[1]
	var cues: AudioCues = s[3]
	w.events.clear()
	w.events.append(GameEvent.make(&"recall_started", 1, me.id, me.id))
	var start: Array[AudioCues.Cue] = cues.collect(w)
	assert_eq(start[0].key, me.id)
	assert_false(start[0].stop)
	w.events.clear()
	w.events.append(GameEvent.make(&"recall_finished", 1, me.id, me.id))
	var end: Array[AudioCues.Cue] = cues.collect(w)
	assert_true(end.any(func(c: AudioCues.Cue) -> bool: return c.id == &"recall_start" and c.stop and c.key == me.id))
	assert_true(_ids(end).has(&"recall_finish"))
