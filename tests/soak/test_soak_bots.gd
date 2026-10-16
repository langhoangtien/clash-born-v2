extends TestCase
## M7.5 soak (chạy riêng: --soak): 10 phút bot đấu bot (Noctis vs Vexa), kiểm INV-06, BOT-11,
## bot kẹt ở chỗ không an toàn, và INV-08 (chạy lại cùng seed ra cùng trạng thái).
## Đủ mọi cặp × 3 seed: tools/bot_matches.gd.

const Inv = preload("res://tests/sim/bots/test_bot_invariants.gd")


func test_M7_5_bot_vs_bot_ten_minutes() -> void:
	var inv: Object = Inv.new()
	var w: World = inv._world(7, &"noctis", &"vexa")
	assert_eq(Inv.run_checks(w, 10.0), "")
	var again: World = inv._world(7, &"noctis", &"vexa")
	for t: int in range(w.tick):
		again.step()
	assert_true(again.state_hash() == w.state_hash(), "INV-08: cùng seed → cùng trạng thái")
