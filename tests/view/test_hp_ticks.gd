extends TestCase
## D-293: khấc trên thanh máu tướng; D-295: khấc mảnh mỗi 500 máu (cố định — số khấc cho biết độ trâu), khấc
## đậm mỗi 1000 máu; không có khấc ở hai mép.


func test_D_295_tick_every_500_big_every_1000() -> void:
	var t: Array[Array] = Bars3D.hp_ticks(2600.0, 110.0)
	assert_eq(t.size(), 5, "2600 máu: khấc ở 500…2500")
	assert_near(t[0][0], 110.0 * 500.0 / 2600.0, 0.001)
	assert_false(t[0][1], "500: khấc mảnh")
	assert_true(t[1][1], "1000: khấc đậm")
	assert_eq(Bars3D.hp_ticks(7000.0, 110.0).size(), 13, "7000 máu: 13 khấc (trước 69 khấc đen kín)")
	assert_eq(Bars3D.hp_ticks(700.0, 110.0).size(), 1, "đầu trận ít khấc, cuối trận nhiều = trâu hơn")


func test_D_293_no_tick_at_bar_end() -> void:
	assert_eq(Bars3D.hp_ticks(1000.0, 110.0).size(), 1, "đúng 1000: khấc ở mép thanh bỏ")
	assert_eq(Bars3D.hp_ticks(400.0, 110.0).size(), 0)
