extends TestCase
## D-333 (ACC.3): bảng Tài khoản — form theo màn, chuyển màn theo trả lời máy chủ, không gửi khi nhập sai.


func _panel() -> Array:
	var p: AccountPanel = AccountPanel.new()
	p.size = Vector2(1920, 1080)
	var sent: Array = []
	p.request.connect(func(a: String, b: Dictionary) -> void: sent.append([a, b]))
	p.show_screen("login")
	return [p, sent]


func _press(p: AccountPanel, text: String) -> void:
	for b: Node in p._box.get_children():
		if b is Button and (b as Button).text == text:
			(b as Button).pressed.emit()
			return
	fail("không có nút " + text)


func test_D_333_login_sends_email_and_password() -> void:
	var made: Array = _panel()
	var p: AccountPanel = made[0]
	p._fields["email"].text = " an@gmail.com "
	p._fields["password"].text = "matkhau123"
	_press(p, "Đăng nhập")
	assert_eq(made[1], [["login", {"email": "an@gmail.com", "password": "matkhau123"}]])
	assert_true(p._fields["password"].secret, "ô mật khẩu che chữ")
	p.free()


func test_D_333_register_then_verify_flow() -> void:
	var made: Array = _panel()
	var p: AccountPanel = made[0]
	_press(p, "Tạo tài khoản")
	assert_eq(p.screen, "register")
	p._fields["email"].text = "an@gmail.com"
	p._fields["password"].text = "matkhau123"
	p._fields["password2"].text = "khac"
	_press(p, "Đăng ký")
	assert_eq(made[1].size(), 0, "hai mật khẩu khác → không gửi")
	p._fields["password2"].text = "matkhau123"
	_press(p, "Đăng ký")
	assert_eq(made[1][0], ["register", {"email": "an@gmail.com", "password": "matkhau123"}])
	p.on_reply("register", true, "", "")
	assert_eq(p.screen, "verify")
	p._fields["code"].text = "123456"
	_press(p, "Xác minh")
	assert_eq(made[1][1], ["verify", {"code": "123456", "email": "an@gmail.com"}], "giữ email qua màn xác minh")
	p.on_reply("verify", false, "BAD_CODE", "Mã không đúng")
	assert_eq(p._message.text, "Mã không đúng")
	p.free()


func test_D_333_not_verified_login_resends_code() -> void:
	var made: Array = _panel()
	var p: AccountPanel = made[0]
	p._fields["email"].text = "an@gmail.com"
	p._fields["password"].text = "matkhau123"
	_press(p, "Đăng nhập")
	p.on_reply("login", false, "NOT_VERIFIED", "")
	assert_eq(p.screen, "verify")
	assert_eq(made[1][-1], ["resend", {"email": "an@gmail.com"}])
	p.free()


func test_D_333_account_state_picks_screen() -> void:
	var p: AccountPanel = _panel()[0]
	p.set_account({"id": 1, "email": "an@gmail.com", "name": ""})
	assert_eq(p.screen, "name", "chưa có tên → đặt tên")
	p.set_account({"id": 1, "email": "an@gmail.com", "name": "Lăng"})
	assert_eq(p.screen, "profile")
	_press(p, "Xóa tài khoản")
	assert_eq(p.screen, "delete", "xóa tài khoản phải xác nhận thêm một bước")
	p.set_account({})
	assert_eq(p.screen, "login", "đăng xuất / đã xóa → màn đăng nhập")
	p.free()


## D-334: Lịch sử trận — bấm từ màn Tài khoản (gửi yêu cầu), trả lời có trận thì hiện từng dòng thắng / thua.
func test_D_334_match_history_screen() -> void:
	var made: Array = _panel()
	var p: AccountPanel = made[0]
	p.set_account({"id": 1, "email": "an@gmail.com", "name": "Lăng"})
	_press(p, "Lịch sử trận")
	assert_eq(made[1][-1], ["history", {}])
	p.on_reply("history", true, "", "", {"matches": [{"won": true, "hero": "duy_anh", "kills": 7, "deaths": 2, "assists": 5,
		"mode": "3v3", "duration_s": 1450.8}]})
	assert_eq(p.screen, "history")
	var lists: Array = p._box.get_children().filter(func(n: Node) -> bool: return n is MatchHistoryList)
	assert_eq(lists.size(), 1)
	assert_eq(MatchHistoryList.lines(p._matches[0]), ["Thắng · Duy Anh · 7/2/5 · 3v3 · 24:10"] as Array[String])
	p.free()


## D-343: lịch sử có cả hai đội — mình (★), người (tên trong game), bot.
func test_D_343_history_lines_both_teams() -> void:
	var m: Dictionary = {"won": false, "hero": "gorran", "kills": 1, "deaths": 2, "assists": 3, "mode": "3v3", "duration_s": 61,
		"allies": [{"hero": "gorran", "me": true, "kills": 1, "deaths": 2, "assists": 3}, {"hero": "myra", "bot": true, "kills": 0, "deaths": 1, "assists": 0}],
		"enemies": [{"hero": "duy_anh", "name": "Lăng", "kills": 4, "deaths": 0, "assists": 1}]}
	assert_eq(MatchHistoryList.lines(m), ["Thua · Gorran · 1/2/3 · 3v3 · 1:01", "Đội mình: ★ Gorran 1/2/3 · Myra (bot) 0/1/0",
		"Đội địch: Duy Anh (Lăng) 4/0/1"] as Array[String])


## D-339: đổi mật khẩu — có mật khẩu thì hỏi mật khẩu hiện tại; tài khoản chỉ Google thì đặt lần đầu.
func test_D_339_change_password_screens() -> void:
	var made: Array = _panel()
	var p: AccountPanel = made[0]
	p.set_account({"id": 1, "email": "an@gmail.com", "name": "Lăng", "has_password": true})
	_press(p, "Đổi mật khẩu")
	assert_eq(p.screen, "password")
	p._fields["old"].text = "cu-12345"
	p._fields["password"].text = "moi-12345"
	p._fields["password2"].text = "moi-12345"
	_press(p, "Lưu mật khẩu")
	assert_eq(made[1][-1], ["password", {"old": "cu-12345", "password": "moi-12345"}])
	assert_true(p._fields["old"].secret, "che mật khẩu hiện tại")
	p.on_reply("password", true, "", "", {"id": 1, "email": "an@gmail.com", "name": "Lăng", "has_password": true})
	assert_eq(p.screen, "profile")
	p.set_account({"id": 2, "email": "g@gmail.com", "name": "G", "has_password": false})
	_press(p, "Đổi mật khẩu")
	assert_eq(p.screen, "password_set", "chỉ Google: không hỏi mật khẩu cũ")
	p.free()


## NET-12 (D-405): ô người đã rớt giữa trận online (bot đánh thay) → lịch sử ghi "(đã rời)" — ở dòng kết quả của mình và
## cạnh người đó trong đội hình.
func test_NET_12_history_marks_left_players() -> void:
	var m: Dictionary = {"won": false, "left": true, "hero": "gorran", "kills": 1, "deaths": 2, "assists": 3, "mode": "1v1",
		"duration_s": 61, "allies": [{"hero": "gorran", "me": true, "left": true, "kills": 1, "deaths": 2, "assists": 3}],
		"enemies": [{"hero": "myra", "name": "Bình", "left": true, "kills": 0, "deaths": 1, "assists": 0}]}
	var l: Array[String] = MatchHistoryList.lines(m)
	assert_true(l[0].begins_with("Thua (đã rời) · "), l[0])
	assert_true(l[1].contains("(đã rời)"), l[1])
	assert_true(l[2].contains("(Bình, đã rời)"), l[2])
	m.erase("left")
	assert_false(MatchHistoryList.lines(m)[0].contains("đã rời"))
