extends TestCase
## M9.2 soak (chạy riêng: --soak): 3v3 toàn bot 10 phút × 3 seed (MATCH-01..05) — INV-06, BOT-11, bot không kẹt;
## INV-08: chạy lại cùng cấu hình ra cùng trạng thái.

const Inv = preload("res://tests/sim/bots/test_bot_invariants.gd")
const SIX: Array[StringName] = [&"brakk", &"myra", &"vexa", &"noctis", &"gorran", &"duy_anh"]


func _cfg(seed: int) -> MatchConfig:
	var heroes: Array[StringName] = SIX.duplicate()
	for k: int in seed % 6:  # xoay vòng tướng theo seed: mỗi seed một đội hình
		heroes.push_back(heroes.pop_front())
	return MatchConfig.make(3, heroes, [], BotState.Difficulty.NORMAL, seed)


func test_M9_2_three_vs_three_bots_ten_minutes() -> void:
	var inv: Object = Inv.new()
	for seed: int in [3, 11, 29]:
		var w: World = inv.team_world(_cfg(seed))
		assert_eq(Inv.run_checks(w, 10.0), "", "seed %d" % seed)
	var a: World = inv.team_world(_cfg(3))
	var b: World = inv.team_world(_cfg(3))
	for t: int in SimClock.seconds_to_ticks(180.0):
		a.step()
		b.step()
	assert_true(a.state_hash() == b.state_hash(), "INV-08: cùng cấu hình → cùng trạng thái")
