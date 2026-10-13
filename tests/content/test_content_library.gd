extends TestCase
## M0.5: thư viện nội dung nạp thư mục, tra theo id, phát hiện id trùng.

const F = preload("res://tests/content/fixture_content.gd")
const TMP: String = "user://test_content_library"


func before_each() -> void:
	_clear(TMP)
	DirAccess.make_dir_recursive_absolute(TMP + "/heroes")


func after_each() -> void:
	_clear(TMP)


func test_real_content_folder_is_valid() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var errs: PackedStringArray = ContentValidator.errors(lib)
	assert_true(errs.is_empty(), "\n".join(errs))


func test_saved_hero_round_trips_through_tres() -> void:
	assert_eq(ResourceSaver.save(F.hero(), TMP + "/heroes/test_brute.tres"), OK)
	var lib: ContentLibrary = ContentLibrary.load_dir(TMP)
	assert_true(lib.heroes.has(&"test_brute"), "tra được theo id")
	var hero: HeroDef = lib.heroes.get(&"test_brute")
	if hero == null:
		return
	assert_eq(hero.q.values[&"damage"].size(), 5)
	assert_eq(hero.r.values[&"cooldown"].size(), 3)
	var passive: EffectDef = (hero.innate.on_learn[0] as ApplyEffectAction).effect
	assert_eq(passive.triggers[0].unique_group, &"bash")
	assert_eq(hero.bot_skill_order[0], HeroDef.Upgrade.Q)
	var errs: PackedStringArray = ContentValidator.errors(lib)
	assert_true(errs.is_empty(), "\n".join(errs))


func test_duplicate_id_across_files_reported() -> void:
	ResourceSaver.save(F.hero(), TMP + "/heroes/a.tres")
	ResourceSaver.save(F.hero(), TMP + "/heroes/b.tres")
	var lib: ContentLibrary = ContentLibrary.load_dir(TMP)
	assert_true("\n".join(lib.load_errors).contains("id trùng 'test_brute'"))


func test_non_game_resource_reported() -> void:
	ResourceSaver.save(ModifierDef.new(), TMP + "/heroes/stray.tres")
	var lib: ContentLibrary = ContentLibrary.load_dir(TMP)
	assert_true("\n".join(lib.load_errors).contains("không phải dữ liệu game"))


func test_missing_id_reported() -> void:
	ResourceSaver.save(EffectDef.new(), TMP + "/heroes/no_id.tres")
	var lib: ContentLibrary = ContentLibrary.load_dir(TMP)
	assert_true("\n".join(lib.load_errors).contains("thiếu id"))


func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub: String in DirAccess.get_directories_at(path):
		_clear(path.path_join(sub))
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
