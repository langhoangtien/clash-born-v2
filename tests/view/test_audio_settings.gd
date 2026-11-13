extends TestCase
## D-414: Nhạc và Âm thanh (tiếng động trận, tiếng nền, giao diện) tách hẳn — lỗi người chơi báo: một nút bật / tắt gộp hai
## thứ (chế độ Bật / Tắt nhạc / Tắt hết), không thể bật nhạc mà tắt tiếng động. Hai công tắc + hai thanh âm lượng riêng, lưu
## riêng, áp đúng bus; tắt cái này không đụng cái kia.

const PATH: String = "user://test_audio_settings.cfg"


func _fresh() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	AudioSettings.use_file(PATH)


func _restore() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	AudioSettings.use_file(AudioSettings.DEFAULT_PATH)


func _muted(bus: String) -> bool:
	return AudioServer.is_bus_mute(AudioServer.get_bus_index(bus))


func test_D_414_music_off_keeps_sounds_on() -> void:
	_fresh()
	AudioSettings.set_music(false)
	assert_false(AudioSettings.music_on)
	assert_true(AudioSettings.sfx_on, "tắt nhạc không đụng âm thanh")
	assert_true(_muted(AudioSettings.MUSIC_BUS))
	assert_false(_muted(AudioSettings.SFX_BUS))
	_restore()


func test_D_414_sounds_off_keeps_music_on() -> void:
	_fresh()
	AudioSettings.set_sfx(false)
	assert_true(AudioSettings.music_on, "tắt âm thanh không đụng nhạc (trước đây không có tổ hợp này)")
	assert_false(_muted(AudioSettings.MUSIC_BUS))
	assert_true(_muted(AudioSettings.SFX_BUS))
	_restore()


func test_D_414_volumes_saved_separately_and_applied_to_buses() -> void:
	_fresh()
	AudioSettings.set_music_volume(0.25)
	AudioSettings.set_sfx_volume(0.8)
	AudioSettings.set_music(false)
	AudioSettings.use_file(PATH)
	assert_near(AudioSettings.music_volume, 0.25, 0.001, "lưu riêng âm lượng nhạc")
	assert_near(AudioSettings.sfx_volume, 0.8, 0.001, "lưu riêng âm lượng âm thanh")
	assert_false(AudioSettings.music_on)
	assert_true(AudioSettings.sfx_on)
	assert_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AudioSettings.MUSIC_BUS)), linear_to_db(0.25), 0.01)
	assert_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AudioSettings.SFX_BUS)), linear_to_db(0.8), 0.01)
	_restore()


## Cài đặt cũ (chế độ gộp) → hai công tắc tương ứng.
func test_D_414_old_combined_mode_migrates() -> void:
	for c: Array in [[0, true, true], [1, false, true], [2, false, false]]:
		_fresh()
		var cfg: ConfigFile = ConfigFile.new()
		cfg.set_value("audio", "mode", c[0])
		cfg.save(PATH)
		AudioSettings.use_file(PATH)
		assert_eq([AudioSettings.music_on, AudioSettings.sfx_on], [c[1], c[2]], "chế độ cũ %d" % c[0])
	_restore()


func test_D_414_players_on_their_own_bus() -> void:
	_fresh()
	var a: AudioView = AudioView.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(a)
	assert_eq(String(a._music.bus), AudioSettings.MUSIC_BUS, "nhạc nền → bus Nhạc")
	assert_eq(String(a._amb.bus), AudioSettings.SFX_BUS, "tiếng nền map → bus Âm thanh")
	assert_true(a._players.all(func(p: AudioStreamPlayer) -> bool: return String(p.bus) == AudioSettings.SFX_BUS), "tiếng động → bus Âm thanh")
	a.free()
	_restore()
