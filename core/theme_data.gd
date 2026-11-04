class_name ThemeData
extends Resource
## 아트 테마. 세계관이 바뀌면 이 리소스가 가리키는 폴더만 통째로 교체한다.
## 폴더 안 구성은 tools/sprite_gen.py 가 만든다 (이름.png + 이름.json).

@export var display_name: String = ""
@export_dir var theme_dir: String = ""

var _sheet_cache: Dictionary = {}


## 애니메이션 시트(이름.png + 이름.json)를 SpriteFrames 로 만든다
func load_sheet(sheet_name: String) -> SpriteFrames:
	if _sheet_cache.has(sheet_name):
		return _sheet_cache[sheet_name]
	var frames := SpriteSheet.build_frames(load_texture(sheet_name), load_json(sheet_name))
	_sheet_cache[sheet_name] = frames
	return frames


func load_texture(asset_name: String) -> Texture2D:
	return load("%s/%s.png" % [theme_dir, asset_name]) as Texture2D


func load_json(asset_name: String) -> Dictionary:
	var path := "%s/%s.json" % [theme_dir, asset_name]
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("테마 JSON 읽기 실패: %s" % path)
	return {}
