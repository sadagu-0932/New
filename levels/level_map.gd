class_name LevelMap
extends RefCounted
## 글자로 그린 맵 파일을 읽는다.
##   #  벽        .  바닥       ~  구덩이 (탄은 지나감)      (공백) 빈칸
##   P  플레이어 시작 (바닥)
##   1~7  구간 시작 지점 (바닥, 디버그 구간 이동·스플릿 지점)
##   그 밖의 글자  소품·적 (바닥). 무엇이 생기는지는 Level.PROPS 에서 정한다

const TILE_SIZE := 16

var width: int = 0
var height: int = 0
var rows: PackedStringArray = []
var spawn_cell: Vector2i = Vector2i.ZERO
## 구간 번호(1~7) → 칸
var section_cells: Dictionary = {}
## 소품·적: [{ "char": 글자, "cell": 칸 }] (읽은 순서 = 위→아래, 왼→오른)
var props: Array[Dictionary] = []


static func load_from_file(path: String) -> LevelMap:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("맵 파일을 읽지 못함: %s" % path)
	return parse(text)


static func parse(text: String) -> LevelMap:
	var map := LevelMap.new()
	for line in text.split("\n"):
		var row := line.trim_suffix("\r")
		if row.begins_with(";"):  # 주석 줄
			continue
		map.rows.append(row)
	while not map.rows.is_empty() and map.rows[map.rows.size() - 1].strip_edges().is_empty():
		map.rows.remove_at(map.rows.size() - 1)
	map.height = map.rows.size()
	for y in map.height:
		var row := map.rows[y]
		map.width = maxi(map.width, row.length())
		for x in row.length():
			var ch := row[x]
			if ch == "P":
				map.spawn_cell = Vector2i(x, y)
			elif ch >= "1" and ch <= "7":
				map.section_cells[int(ch)] = Vector2i(x, y)
			elif ch != "#" and ch != "." and ch != " " and ch != "~":
				map.props.append({"char": ch, "cell": Vector2i(x, y)})
	return map


func char_at(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= height:
		return " "
	var row := rows[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return " "
	return row[cell.x]


func is_wall(cell: Vector2i) -> bool:
	return char_at(cell) == "#"


func is_pit(cell: Vector2i) -> bool:
	return char_at(cell) == "~"


func is_floor(cell: Vector2i) -> bool:
	var ch := char_at(cell)
	return ch != "#" and ch != " " and ch != "~"


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_SIZE) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5


func pixel_size() -> Vector2i:
	return Vector2i(width, height) * TILE_SIZE
