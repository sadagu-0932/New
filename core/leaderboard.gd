class_name Leaderboard
extends RefCounted
## 통합 리더보드 하나. 로컬 JSON (user://leaderboard.json), 상위 N명.
## 항목: { initials, ticks, skill_id, split_ticks, order }  (order = 등록 순서, 같은 기록이면 먼저 낸 사람이 위)

static var path: String = "user://leaderboard.json"


static func size_limit() -> int:
	return DB.game_config.leaderboard_size


static func load_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and (parsed as Dictionary).get("entries") is Array:
		for e: Variant in (parsed as Dictionary)["entries"]:
			if e is Dictionary:
				var d := e as Dictionary
				d["ticks"] = int(d.get("ticks", 0))
				d["order"] = int(d.get("order", 0))
				var splits: Array[int] = []
				for s: Variant in d.get("split_ticks", []):
					splits.append(int(s))
				d["split_ticks"] = splits
				out.append(d)
	_sort(out)
	return out


static func save_entries(entries: Array[Dictionary]) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("리더보드 저장 실패: %s" % path)
		return
	f.store_string(JSON.stringify({"entries": entries}, "  "))


static func _sort(entries: Array[Dictionary]) -> void:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["ticks"] != b["ticks"]:
			return a["ticks"] < b["ticks"]
		return a["order"] < b["order"])


## 이 기록이 순위에 들어가면 몇 위인지 (1부터). 못 들어가면 0
static func rank_for(ticks: int) -> int:
	var entries := load_entries()
	var rank := 1
	for e in entries:
		if e["ticks"] <= ticks:
			rank += 1
	return rank if rank <= size_limit() else 0


## 등록하고 순위를 돌려준다 (못 들어가면 0)
static func submit(initials: String, result: RunResult) -> int:
	var entries := load_entries()
	var next_order := 0
	for e in entries:
		next_order = maxi(next_order, int(e["order"]) + 1)
	var entry := {
		"initials": initials.to_upper().left(3),
		"ticks": result.total_ticks,
		"skill_id": result.skill_id,
		"split_ticks": result.split_ticks,
		"order": next_order,
	}
	entries.append(entry)
	_sort(entries)
	var rank := entries.find(entry) + 1
	while entries.size() > size_limit():
		entries.pop_back()
	save_entries(entries)
	return rank if rank <= size_limit() else 0


## 1위 기록 (스플릿 비교 기준, 없으면 빈 Dictionary)
static func best() -> Dictionary:
	var entries := load_entries()
	return entries[0] if not entries.is_empty() else {}


## 관리자: 백업 파일로 복사하고 경로를 돌려준다
static func backup() -> String:
	if not FileAccess.file_exists(path):
		return ""
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var dest := path.get_basename() + "_backup_" + stamp + ".json"
	DirAccess.copy_absolute(path, dest)
	return dest


## 관리자: 전부 지운다
static func clear() -> void:
	save_entries([])
