extends TestCase
## D-260: làm nóng shader lúc vào trận — một bản mọi mô hình (mỗi phe, kèm bản mờ), công trình, đạn, mảnh hiệu ứng;
## vẽ vài khung rồi tự gỡ.


func test_D_260_covers_every_model_and_frees_after_frames() -> void:
	var arts: Array = ShaderWarmup.sample_entities().map(func(e: Entity) -> String: return "%s/%d/%d" % [e.art_id, e.team, e.tier])
	assert_true(arts.has("duy_anh/0/0") and arts.has("duy_anh/1/0"), "hero hai phe")
	assert_true(arts.has("neutral_wolf/2/0"), "quái rừng")
	assert_true(arts.has("tower/1/3") and arts.has("core/0/0"), "trụ theo bậc, nhà chính")
	var w: ShaderWarmup = ShaderWarmup.make(Projectiles3D.new(), Vector3.ZERO)
	assert_true(w.count() > arts.size(), "mô hình + bản mờ + đạn + hiệu ứng")
	for i: int in ShaderWarmup.FRAMES - 1:
		w.step()
	assert_false(w.done)
	w.step()
	assert_true(w.done, "vẽ đủ khung thì xong")
	w.free()
