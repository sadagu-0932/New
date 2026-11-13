class_name TutorialData
extends Resource
## 튜토리얼 전체 설정. 실제 값은 res://data/tutorial.tres
## 구간 맵 파일 7개를 왼쪽부터 이어 붙여 맵 하나로 만든다 (고정 맵, 랜덤 없음).

@export var sections: Array[TutorialSectionData] = []
## 스토리 트리거 발동 거리 (px)
@export var story_trigger_radius: float = 0.0
## 출발 전(첫 조작 전) 하단 안내 문구. 가장 먼저 스킬 설정 방법을 알려준다
@export_multiline var pre_start_hint: String = ""
## 타일 그림 (첫 번째가 기본). 스토리판 프롤로그는 연구소 지하라 tiles_lab
@export var tilesets: Array[String] = ["tiles"]
## 표지판 글상자가 보이는 거리 (px)
@export var sign_radius: float = 0.0


## 구간 파일들을 이어 붙인 글자 맵. 맨 왼쪽에 벽 한 줄을 붙인다.
func assemble_text() -> String:
	var blocks: Array[PackedStringArray] = []
	var height := -1
	for i in sections.size():
		var rows := _read_rows(sections[i].map_file)
		if height < 0:
			height = rows.size()
		elif rows.size() != height:
			push_error("구간 %d 맵 높이가 다름: %d (기대 %d)" % [i + 1, rows.size(), height])
		blocks.append(rows)
	var out := PackedStringArray()
	for y in maxi(height, 0):
		var line := "#"
		for rows in blocks:
			line += rows[y] if y < rows.size() else ""
		out.append(line)
	return "\n".join(out)


static func _read_rows(path: String) -> PackedStringArray:
	var rows := PackedStringArray()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("구간 맵 파일을 읽지 못함: %s" % path)
	for line in text.split("\n"):
		var row := line.trim_suffix("\r")
		if row.begins_with(";") or row.strip_edges().is_empty():
			continue
		rows.append(row)
	return rows
