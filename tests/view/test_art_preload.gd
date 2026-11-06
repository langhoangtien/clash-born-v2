extends TestCase
## D-269: hình có thể hiện giữa trận (icon đồ, chiêu, buff, chân dung) nạp ngầm từ đầu trận — lần hiện đầu
## không phải đọc đĩa giữa trận (log 0.1.455: 15 lần đứng ~130 ms trong _process).


func test_D_269_load_ahead_then_texture_returns_same_image() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var ids: Array[StringName] = ArtLibrary.content_ids(lib)
	var item_icon: StringName = lib.items.values()[0].art_id
	assert_true(ids.has(item_icon), "gồm icon đồ")
	assert_true(ids.has(StringName(String(lib.heroes.keys()[0]) + "_portrait")), "gồm chân dung hero")
	ArtLibrary.clear_for_test()
	ArtLibrary.load_ahead(ids)
	var tex: Texture2D = ArtLibrary.texture(item_icon)
	assert_true(tex != null, "lấy được hình đã nạp ngầm")
	assert_eq(ArtLibrary.texture(item_icon), tex, "lần sau lấy từ bộ nhớ")
	assert_false(ArtLibrary.is_pending(item_icon))


func test_D_269_missing_art_ignored() -> void:
	ArtLibrary.load_ahead([&"khong_co_hinh_nay", &""])
	assert_true(ArtLibrary.texture(&"khong_co_hinh_nay") == null, "thiếu hình: vẫn trả null, không lỗi")
