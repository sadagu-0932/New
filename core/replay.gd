class_name Replay
extends RefCounted
## 리플레이 = 시작 조건(시드·스킬) + 틱별 입력. 같은 조건에 같은 입력을 넣으면 같은 판이 재현된다 (결정론).
## 저장 형식: 같은 입력이 이어지는 구간을 묶어서 [반복 수, 이동x, 이동y, 조준x, 조준y, 누름, 새로누름] (이동은 ×127 정수)
## 1위 기록의 리플레이를 user://best_replay.json 에 저장 → 어트랙트 모드, 나중에 고스트에 사용.

const MOVE_SCALE := 127.0

static var best_path: String = "user://best_replay.json"

var seed_value: int = 0
var skill_id: String = ""
var frames: Array[InputFrame] = []
## 표시용 정보
var initials: String = ""
var total_ticks: int = 0


func to_dict() -> Dictionary:
	var runs: Array = []
	var last: Array = []
	for f in frames:
		var row := [roundi(f.move.x * MOVE_SCALE), roundi(f.move.y * MOVE_SCALE), roundi(f.aim.x), roundi(f.aim.y), f.held, f.pressed]
		if not runs.is_empty() and row == last:
			runs[runs.size() - 1][0] += 1
		else:
			runs.append([1] + row)
			last = row
	return {"version": 1, "seed": seed_value, "skill_id": skill_id, "initials": initials,
		"total_ticks": total_ticks, "frame_count": frames.size(), "runs": runs}


static func from_dict(d: Dictionary) -> Replay:
	var r := Replay.new()
	r.seed_value = int(d.get("seed", 0))
	r.skill_id = String(d.get("skill_id", ""))
	r.initials = String(d.get("initials", ""))
	r.total_ticks = int(d.get("total_ticks", 0))
	for run: Variant in d.get("runs", []):
		var a: Array = run
		for i in int(a[0]):
			var f := InputFrame.new()
			f.move = Vector2(int(a[1]), int(a[2])) / MOVE_SCALE
			f.aim = Vector2(int(a[3]), int(a[4]))
			f.held = int(a[5])
			f.pressed = int(a[6])
			r.frames.append(f)
	return r


func save(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("리플레이 저장 실패: %s" % path)
		return false
	f.store_string(JSON.stringify(to_dict()))
	return true


static func load_file(path: String) -> Replay:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return from_dict(parsed) if parsed is Dictionary else null


static func load_best() -> Replay:
	return load_file(best_path)


static func delete_best() -> void:
	if FileAccess.file_exists(best_path):
		DirAccess.remove_absolute(best_path)


## 재생용 입력 공급원
func make_source() -> ScriptedInputSource:
	var src := ScriptedInputSource.new()
	for f in frames:
		src.push_frame(f.duplicate_frame())
	return src
