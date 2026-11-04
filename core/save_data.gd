class_name SaveData
extends RefCounted
## 간단한 로컬 세이브 (user:// 의 JSON). 컷씬 시청 여부 등 기록 외의 진행 정보.
## TODO(M7): 리더보드는 별도 파일로 저장

static var path: String = "user://save.json"
static var _cache: Dictionary = {}
static var _loaded_path: String = ""


static func get_value(key: String, default: Variant = null) -> Variant:
	_ensure_loaded()
	return _cache.get(key, default)


static func set_value(key: String, value: Variant) -> void:
	_ensure_loaded()
	_cache[key] = value
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("세이브 저장 실패: %s" % path)
		return
	f.store_string(JSON.stringify(_cache, "  "))


## 테스트용: 다른 파일을 쓰고 내용을 비운다
static func use_file(new_path: String, clear: bool = false) -> void:
	path = new_path
	_loaded_path = ""
	if clear and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _ensure_loaded() -> void:
	if _loaded_path == path:
		return
	_loaded_path = path
	_cache = {}
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_cache = parsed
