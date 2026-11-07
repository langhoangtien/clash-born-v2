extends TestCase
## D-293: khấc trên thanh máu tướng — mảnh mỗi 100 máu, đậm mỗi 1000 máu; không có khấc ở hai đầu thanh.


func test_D_293_ticks_every_100_hp_big_every_1000() -> void:
	var t: Array[Array] = Bars3D.hp_ticks(710.0, 110.0)
	assert_eq(t.size(), 7, "710 máu: khấc ở 100…700")
	assert_near(t[0][0], 110.0 * 100.0 / 710.0, 0.001)
	assert_false(t[0][1])
	var big: Array[Array] = Bars3D.hp_ticks(2500.0, 110.0)
	assert_eq(big.size(), 24)
	assert_true(big[9][1], "1000 máu: khấc đậm")
	assert_true(big[19][1], "2000 máu: khấc đậm")
	assert_false(big[10][1])


func test_D_293_no_tick_at_bar_end() -> void:
	assert_eq(Bars3D.hp_ticks(1000.0, 110.0).size(), 9, "đúng 1000: khấc cuối là mép thanh, bỏ")
	assert_eq(Bars3D.hp_ticks(80.0, 110.0).size(), 0)
