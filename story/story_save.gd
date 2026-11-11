class_name StorySave
extends RefCounted
## 스토리판 저장 파일 (user://saves/*.json).
## 칸은 수동 1개(manual) + 자동 여러 개(auto_1..N, data/save.tres 의 auto_slots).
## 자동저장은 빈 칸 → 없으면 가장 오래된 자동 칸을 덮어쓴다. 수동 칸은 자동저장이 건드리지 않는다.
## 저장마다 순번(seq)이 1씩 늘어난다 → 시계가 바뀌어도 "어느 것이 최신인지"가 흔들리지 않는다.

const VERSION := 1
const MANUAL := "manual"
const AUTO := "auto"

## 테스트용: 다른 폴더를 쓰려면 바꾼다 ("" = data/save.tres 의 save_dir)
static var dir_override: String = ""


static func dir() -> String:
	return dir_override if not dir_override.is_empty() else DB.save.save_dir


static func _path(slot: String) -> String:
	return "%s/%s.json" % [dir(), slot]


static func _slots() -> Array[String]:
	var out: Array[String] = [MANUAL]
	for i in DB.save.auto_slots:
		out.append("%s_%d" % [AUTO, i + 1])
	return out


static func _read(slot: String) -> Dictionary:
	var path := _path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or int((parsed as Dictionary).get("version", 0)) != VERSION:
		return {}
	var d := parsed as Dictionary
	d["slot"] = slot
	return d


## 모든 저장. 최신이 맨 앞, 가장 오래된 것이 맨 뒤
static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in _slots():
		var d := _read(slot)
		if not d.is_empty():
			out.append(d)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["seq"]) > int(b["seq"]))
	return out


## 가장 최근 저장 (없으면 빈 Dictionary)
static func latest() -> Dictionary:
	var all := list()
	return all[0] if not all.is_empty() else {}


static func has_any() -> bool:
	return not list().is_empty()


## 수동 저장 (칸 하나를 계속 덮어쓴다)
static func write_manual(state: Dictionary) -> bool:
	return _write(MANUAL, MANUAL, state)


## 자동저장: 빈 자동 칸, 없으면 가장 오래된 자동 칸에
static func write_auto(state: Dictionary) -> bool:
	var target := ""
	var oldest_seq := -1
	for slot in _slots():
		if slot == MANUAL:
			continue
		var d := _read(slot)
		if d.is_empty():
			target = slot
			break
		if oldest_seq < 0 or int(d["seq"]) < oldest_seq:
			oldest_seq = int(d["seq"])
			target = slot
	if target.is_empty():
		return false
	return _write(target, AUTO, state)


static func _write(slot: String, kind: String, state: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir())
	var seq := 1
	for d in list():
		seq = maxi(seq, int(d["seq"]) + 1)
	var now := Time.get_datetime_dict_from_system()
	var data := {
		"version": VERSION,
		"kind": kind,
		"seq": seq,
		"saved_at": "%04d-%02d-%02d %02d:%02d" % [now["year"], now["month"], now["day"], now["hour"], now["minute"]],
		"state": state,
	}
	var f := FileAccess.open(_path(slot), FileAccess.WRITE)
	if f == null:
		push_warning("저장 실패: %s" % _path(slot))
		return false
	f.store_string(JSON.stringify(data, "  "))
	return true


## 모든 저장 삭제 (테스트용)
static func clear_all() -> void:
	for slot in _slots():
		if FileAccess.file_exists(_path(slot)):
			DirAccess.remove_absolute(_path(slot))
