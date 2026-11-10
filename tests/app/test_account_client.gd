extends TestCase
## D-333 (ACC.3): AccountClient giữ phiên — có token thì lưu (không lưu mật khẩu), đăng xuất / phiên hết hạn thì xóa.


func test_D_333_session_saved_and_cleared() -> void:
	var keep: String = AccountClient.token
	var keep_acc: Dictionary = AccountClient.account
	var had: bool = FileAccess.file_exists(AccountClient.FILE)
	var saved: String = FileAccess.get_file_as_string(AccountClient.FILE) if had else ""
	var c: AccountClient = AccountClient.new()
	c._action = "login"
	c._finish(true, "", "", {"token": "tok-1", "account": {"id": 3, "email": "an@gmail.com", "name": "Lăng"}})
	assert_true(AccountClient.signed_in())
	assert_eq(AccountClient.account["name"], "Lăng")
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(AccountClient.FILE)
	assert_eq(cfg.get_value("session", "token", ""), "tok-1", "lưu token phiên")
	assert_false(FileAccess.get_file_as_string(AccountClient.FILE).contains("password"), "không lưu mật khẩu")
	c._action = "me"
	c._finish(false, "NO_SESSION", "hết hạn", {})
	assert_false(AccountClient.signed_in(), "phiên hết hạn → đăng xuất")
	cfg.load(AccountClient.FILE)
	assert_eq(cfg.get_value("session", "token", "x"), "")
	c.free()
	AccountClient.token = keep
	AccountClient.account = keep_acc
	if had:
		var f: FileAccess = FileAccess.open(AccountClient.FILE, FileAccess.WRITE)
		f.store_string(saved)
	else:
		DirAccess.remove_absolute(AccountClient.FILE)
