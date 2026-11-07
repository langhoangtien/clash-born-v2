extends TestCase
## D-148: tự cập nhật — chỉ mời khi biết bản đang chạy và bản trên mạng mới hơn.


func test_D_148_newer_only_when_code_greater() -> void:
	assert_true(Updater.is_newer({"code": 181}, 180))
	assert_false(Updater.is_newer({"code": 180}, 180))
	assert_false(Updater.is_newer({"code": 179}, 180))
	assert_false(Updater.is_newer({}, 180))


func test_D_148_unknown_current_never_prompts() -> void:
	assert_false(Updater.is_newer({"code": 999}, 0), "chạy từ editor / PC: không mời")


func test_D_148_disabled_off_android() -> void:
	assert_false(Updater.enabled(), "test không chạy trên Android")


func test_D_281_domain_first_github_fallback() -> void:
	assert_eq(Updater.SITES[0], "https://clashborn.quest/", "hỏi VPS trước")
	assert_true(Updater.SITES[-1].contains("github.io"), "GitHub dự phòng")


func test_D_281_apk_url_relative_or_absolute() -> void:
	assert_eq(Updater.apk_url("https://clashborn.quest/", {"apk": "releases/clashborn-0.1.9.apk"}),
		"https://clashborn.quest/releases/clashborn-0.1.9.apk")
	assert_eq(Updater.apk_url("https://a/", {"apk": "https://b/x.apk"}), "https://b/x.apk", "đường dẫn đầy đủ giữ nguyên")
	assert_eq(Updater.apk_url("https://a/", {}), "https://a/clashborn.apk", "version.json cũ (GitHub)")


func test_D_281_sha256_checked_before_install() -> void:
	var path: String = OS.get_user_data_dir().path_join("test_update.apk")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("clashborn")
	f.close()
	var good: String = FileAccess.get_sha256(path)
	assert_true(Updater.verified(path, {"sha256": good}))
	assert_true(Updater.verified(path, {"sha256": good.to_upper()}), "không phân biệt hoa thường")
	assert_false(Updater.verified(path, {"sha256": "00" + good.substr(2)}), "sai mã băm: không cài")
	assert_true(Updater.verified(path, {}), "version.json cũ không có sha256: cho cài như trước")
	DirAccess.remove_absolute(path)
