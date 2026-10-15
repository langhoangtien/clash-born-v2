class_name ContentLibrary
extends RefCounted
## Nạp mọi file .tres trong một thư mục (mặc định content/) và tra theo id.
## Id là duy nhất trong toàn bộ thư viện.

const DEFAULT_ROOT: String = "res://content"
## Thư mục chứa thiết lập (BalanceSettings…), không phải dữ liệu có id.
const SETTINGS_DIRS: PackedStringArray = ["balance"]

var heroes: Dictionary[StringName, HeroDef] = {}
var abilities: Dictionary[StringName, AbilityDef] = {}
var effects: Dictionary[StringName, EffectDef] = {}
var items: Dictionary[StringName, ItemDef] = {}
var units: Dictionary[StringName, UnitDef] = {}
## JGL-06: theo loại trại (CampDef.kind).
var camps: Dictionary[StringName, CampDef] = {}
var load_errors: PackedStringArray = PackedStringArray()

var _all: Dictionary[StringName, String] = {}  # id → đường dẫn file


static func load_dir(root: String = DEFAULT_ROOT) -> ContentLibrary:
	var lib: ContentLibrary = ContentLibrary.new()
	var paths: PackedStringArray = PackedStringArray()
	_collect(root, paths)
	paths.sort()
	for path: String in paths:
		lib._add(path, load(path))
	return lib


func file_count() -> int:
	return _all.size()


func _add(path: String, resource: Resource) -> void:
	if resource == null:
		load_errors.append("không nạp được: " + path)
		return
	if not resource is GameDef:
		load_errors.append("không phải dữ liệu game (GameDef): " + path)
		return
	var def: GameDef = resource as GameDef
	if def.id.is_empty():
		load_errors.append("thiếu id: " + path)
		return
	if _all.has(def.id):
		load_errors.append("id trùng '%s': %s và %s" % [def.id, _all[def.id], path])
		return
	_all[def.id] = path
	if def is HeroDef:
		heroes[def.id] = def
	elif def is AbilityDef:
		abilities[def.id] = def
	elif def is EffectDef:
		effects[def.id] = def
	elif def is ItemDef:
		items[def.id] = def
	elif def is UnitDef:
		units[def.id] = def
	elif def is CampDef:
		camps[(def as CampDef).kind] = def


## Bản xuất (export) đổi .tres thành .remap; bỏ đuôi đó để nạp được ở cả hai.
static func _collect(dir_path: String, out: PackedStringArray) -> void:
	for sub: String in DirAccess.get_directories_at(dir_path):
		if SETTINGS_DIRS.has(sub):
			continue
		_collect(dir_path.path_join(sub), out)
	for file: String in DirAccess.get_files_at(dir_path):
		var name: String = file.trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			out.append(dir_path.path_join(name))
