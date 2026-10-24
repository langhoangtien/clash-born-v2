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
