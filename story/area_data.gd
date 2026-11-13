class_name AreaData
extends Resource
## 지역 하나 (맵 하나). res://data/areas/ 아래에 .tres 를 넣으면 자동으로 등록된다.
## 스토리판의 바깥 세상은 맵 한 장(world)에 전부 이어져 있다. 화면이 바뀌는 것은 프롤로그(튜토리얼 맵) ↔ 세상 사이뿐.
## 세상 맵에는 같은 크기의 글자 맵이 두 장 더 딸려 있다:
##   ground_file   칸마다 땅 종류 (숲·연구소·마을 흙·철길·쓰러진 나무 길) → 타일 그림·지도 색·나무 베기 여부
##   regions_file  칸마다 지역 글자 → zones (구불구불한 모양의 지역들)
## 맵 글자 중 스토리용: E 출입구 · Y 웨이스톤 · $ 획득물 · N NPC · I 표지판 · R 잔해(막힘)
## 같은 글자가 여러 개면 맵에서 읽는 순서(위→아래, 왼→오른)대로 아래 목록과 짝지어진다.
## 적은 새로 만들지 않고 기존 글자(C c S B Z)를 쓰며, 지역별 차이는 enemy_overrides 의 수치 데이터로만 낸다.

@export var id: String = ""
@export var display_name: String = ""
## 글자 맵 파일. 비어 있으면 튜토리얼(프롤로그) 맵을 쓴다
@export_file("*.txt") var map_file: String = ""
## 땅 종류 맵·지역 맵 (map_file 과 같은 크기. 없으면 전부 기본 타일·지역 없음)
@export_file("*.txt") var ground_file: String = ""
@export_file("*.txt") var regions_file: String = ""
## 기본 타일 그림 (땅 종류 맵이 없거나 모르는 글자일 때)
@export var tileset: String = "tiles"
## 땅 종류 글자 → 타일 그림 / 지도 색 (바닥, 벽·나무·집)
@export var ground_tilesets: Dictionary = {}
@export var ground_floor_colors: Dictionary = {}
@export var ground_wall_colors: Dictionary = {}
## 벽(나무)을 근접 공격으로 베어 지나갈 수 있는 땅 종류 글자들 (예: "grt")
@export var breakable_grounds: String = ""
## 몇 번 쳐야 베어지는지, 벨 때마다 얻는 아이템 id ("" = 없음)
@export var break_hits: int = 0
@export var break_drop_item: String = ""
## 나무를 벨 때마다 채워지는 탄약 (발)
@export var break_ammo: int = 0
## 지도 화면이 있는 지역인지 (프롤로그는 없다)
@export var on_map: bool = true
## 이 맵 안의 지역들 (연구소·광산촌·쓰러진 숲 … 구불구불한 모양)
@export var zones: Array[ZoneData] = []
## 보스방: 이 네모 안에서는 보스를 쓰러뜨리기(boss_cleared_flag) 전까지 저장·순간이동 불가
@export var boss_room_rect: Rect2i = Rect2i()
@export var boss_cleared_flag: String = ""
## 이름 붙은 지점들 (이름 → 칸). 세상 생성기가 적어 준다 (철길 중간, 길을 막은 나무 자리 등)
@export var landmarks: Dictionary = {}
## 맵 글자 → 적 데이터 이름 (지역 설정에 없을 때)
@export var enemy_overrides: Dictionary = {}
@export var exits: Array[AreaExitData] = []
@export var waystones: Array[WaystoneData] = []
## 획득물 아이템 id
@export var pickups: Array[String] = []
@export var npcs: Array[NpcData] = []
## 표지판 글
@export var signs: Array[String] = []

var _map: LevelMap


## 이 지역의 맵 (지도 화면·순간이동 도착 지점 계산용, 한 번만 읽는다)
func level_map() -> LevelMap:
	if _map == null:
		if map_file.is_empty():
			_map = LevelMap.parse(DB.game_config.tutorial.assemble_text())
		else:
			_map = LevelMap.load_from_file(map_file)
	return _map


## 맵에서 글자 ch 가 있는 칸들 (읽는 순서)
func prop_cells(ch: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for entry: Dictionary in level_map().props:
		if entry["char"] == ch:
			out.append(entry["cell"])
	return out


## 도착 지점 (0 = P, 1~7 = 숫자 칸) 의 위치 (px)
func spawn_position(index: int) -> Vector2:
	var m := level_map()
	return LevelMap.cell_center(m.section_cells.get(index, m.spawn_cell) if index > 0 else m.spawn_cell)


func waystone_index(waystone_id: String) -> int:
	for i in waystones.size():
		if waystones[i].id == waystone_id:
			return i
	return -1


## 웨이스톤으로 순간이동했을 때 서는 자리 (웨이스톤 한 칸 아래)
func waystone_arrival(waystone_id: String) -> Vector2:
	var cells := prop_cells("Y")
	var i := waystone_index(waystone_id)
	if i < 0 or i >= cells.size():
		return spawn_position(0)
	return LevelMap.cell_center(cells[i] + Vector2i.DOWN)


var _ground: PackedStringArray
var _regions: PackedStringArray
var _zone_by_key: Dictionary = {}
var _zone_centers: Dictionary = {}


static func _read_grid(path: String) -> PackedStringArray:
	var rows := PackedStringArray()
	if path.is_empty():
		return rows
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var row := line.trim_suffix("\r")
		if not row.is_empty() and not row.begins_with(";"):
			rows.append(row)
	return rows


func _ensure_grids() -> void:
	if not _zone_by_key.is_empty() or zones.is_empty():
		if _ground.is_empty() and not ground_file.is_empty():
			_ground = _read_grid(ground_file)
		return
	_ground = _read_grid(ground_file)
	_regions = _read_grid(regions_file)
	for z in zones:
		_zone_by_key[z.key] = z


static func _char(rows: PackedStringArray, cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= rows.size():
		return ""
	var row := rows[cell.y]
	return row[cell.x] if cell.x >= 0 and cell.x < row.length() else ""


## 그 칸의 땅 종류 글자 ("" = 정해지지 않음)
func ground_at(cell: Vector2i) -> String:
	_ensure_grids()
	return _char(_ground, cell)


## 그 칸이 든 지역 (없으면 null)
func zone_at(cell: Vector2i) -> ZoneData:
	_ensure_grids()
	return _zone_by_key.get(_char(_regions, cell))


## 그 위치(px)가 든 지역
func zone_at_pos(pos: Vector2) -> ZoneData:
	return zone_at(Vector2i((pos / LevelMap.TILE_SIZE).floor()))


func zone(zone_id: String) -> ZoneData:
	for z in zones:
		if z.id == zone_id:
			return z
	return null


## 지역의 한가운데쯤 (그 지역 칸들의 평균 자리, 지도에 이름을 놓을 곳)
func zone_center(zone_id: String) -> Vector2:
	_ensure_grids()
	if _zone_centers.is_empty():
		var sums: Dictionary = {}
		var counts: Dictionary = {}
		for y in _regions.size():
			var row := _regions[y]
			for x in row.length():
				var k := row[x]
				sums[k] = (sums.get(k, Vector2.ZERO) as Vector2) + Vector2(x, y)
				counts[k] = int(counts.get(k, 0)) + 1
		for z in zones:
			if counts.has(z.key):
				_zone_centers[z.id] = (sums[z.key] as Vector2) / float(counts[z.key])
	return _zone_centers.get(zone_id, Vector2.ZERO)


## 그 묶음에 든 지역들
func zones_in_group(group_id: String) -> Array[ZoneData]:
	var out: Array[ZoneData] = []
	for z in zones:
		if z.group == group_id:
			out.append(z)
	return out


## 묶음들 (id → 이름), 지역 목록 순서대로
func groups() -> Dictionary:
	var out: Dictionary = {}
	for z in zones:
		if not out.has(z.group):
			out[z.group] = z.group_name
	return out


## 묶음의 한가운데쯤 (그 묶음에 든 지역 한가운데들의 평균)
func group_center(group_id: String) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for z in zones_in_group(group_id):
		sum += zone_center(z.id)
		n += 1
	return sum / float(maxi(n, 1))


## 이름 붙은 지점의 칸 (없으면 (-1, -1))
func landmark(mark: String) -> Vector2i:
	return landmarks.get(mark, Vector2i(-1, -1))


## 그 칸의 타일 그림 이름
func tileset_at(cell: Vector2i) -> String:
	return String(ground_tilesets.get(ground_at(cell), tileset))


## 이 지역에서 쓰는 타일 그림 전부
func tilesets() -> Array[String]:
	var out: Array[String] = [tileset]
	for name: String in ground_tilesets.values():
		if not out.has(name):
			out.append(name)
	return out


## 그 칸의 벽을 벨 수 있는 땅인지
func breakable_at(cell: Vector2i) -> bool:
	var g := ground_at(cell)
	return not g.is_empty() and breakable_grounds.contains(g)


## 그 칸에 놓인 맵 글자의 적 데이터 이름 (없으면 fallback)
func enemy_key_at(cell: Vector2i, ch: String, fallback: String) -> String:
	var z := zone_at(cell)
	if z != null and z.enemy_overrides.has(ch):
		return String(z.enemy_overrides[ch])
	return String(enemy_overrides.get(ch, fallback))


## 그 위치의 이름 (지역 이름, 이름 없는 땅이면 맵 이름)
func place_name(pos: Vector2) -> String:
	var z := zone_at_pos(pos)
	return z.display_name if z != null and not z.display_name.is_empty() else display_name


## 그 위치(px)가 아직 쓰러뜨리지 않은 보스의 방 안인지
func in_boss_room(pos: Vector2) -> bool:
	return boss_room_rect.has_area() and boss_room_rect.has_point(Vector2i((pos / LevelMap.TILE_SIZE).floor())) \
		and not Story.has_flag(boss_cleared_flag)
