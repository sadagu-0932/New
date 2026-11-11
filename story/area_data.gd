class_name AreaData
extends Resource
## 지역 하나 (맵 하나). res://data/areas/ 아래에 .tres 를 넣으면 자동으로 등록된다.
## 스토리판의 바깥 세상은 지역 하나(world)에 전부 이어져 있고, 그 안의 연구소·광산촌·숲 등은 구역(zones)이다.
## 화면이 바뀌는 것은 프롤로그(튜토리얼 맵) ↔ 세계 사이뿐이다.
## 맵 글자 중 스토리용: E 출입구 · Y 웨이스톤 · $ 획득물 · N NPC · I 표지판 · R 잔해(막힘)
## 같은 글자가 여러 개면 맵에서 읽는 순서(위→아래, 왼→오른)대로 아래 목록과 짝지어진다.
## 적은 새로 만들지 않고 기존 글자(C c S B Z)를 쓰며, 구역별 차이는 enemy_overrides 의 수치 데이터로만 낸다.
## 여기의 tileset·breakable_walls·지도 색은 어느 구역에도 들지 않는 땅(들판)의 것이다.

@export var id: String = ""
@export var display_name: String = ""
## 글자 맵 파일. 비어 있으면 튜토리얼(프롤로그) 맵을 쓴다
@export_file("*.txt") var map_file: String = ""
## 타일 그림 (art 테마의 시트 이름)
@export var tileset: String = "tiles"
## 지도 화면이 있는 지역인지 (프롤로그는 없다)
@export var on_map: bool = true
## 지도에서의 지형 색 (들판의 바닥 / 나무)
@export var map_floor_color: Color = Color(0.56, 0.52, 0.62)
@export var map_wall_color: Color = Color(0.24, 0.21, 0.3)
## 이 지역 안의 구역들 (연구소·광산촌·숲 …)
@export var zones: Array[ZoneData] = []
## 벽(나무)을 근접 공격으로 베어 지나갈 수 있는지, 몇 번 쳐야 베어지는지, 벨 때마다 얻는 아이템 id ("" = 없음)
@export var breakable_walls: bool = false
@export var break_hits: int = 0
@export var break_drop_item: String = ""
## 맵 글자 → 적 데이터 이름 (data/enemies/ 의 파일 이름). 없는 글자는 기본 적
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


## 그 칸이 든 구역 (없으면 null = 들판)
func zone_at(cell: Vector2i) -> ZoneData:
	for z in zones:
		if z.rect.has_point(cell):
			return z
	return null


## 그 위치(px)가 든 구역
func zone_at_pos(pos: Vector2) -> ZoneData:
	return zone_at(Vector2i((pos / LevelMap.TILE_SIZE).floor()))


func zone(zone_id: String) -> ZoneData:
	for z in zones:
		if z.id == zone_id:
			return z
	return null


## 그 칸의 타일 그림 이름
func tileset_at(cell: Vector2i) -> String:
	var z := zone_at(cell)
	return z.tileset if z != null else tileset


## 이 지역에서 쓰는 타일 그림 전부
func tilesets() -> Array[String]:
	var out: Array[String] = [tileset]
	for z in zones:
		if not out.has(z.tileset):
			out.append(z.tileset)
	return out


## 그 칸의 벽을 벨 수 있는 땅인지
func breakable_at(cell: Vector2i) -> bool:
	var z := zone_at(cell)
	return z.breakable_walls if z != null else breakable_walls


## 그 칸에 놓인 맵 글자의 적 데이터 이름 (없으면 fallback)
func enemy_key_at(cell: Vector2i, ch: String, fallback: String) -> String:
	var z := zone_at(cell)
	if z != null and z.enemy_overrides.has(ch):
		return String(z.enemy_overrides[ch])
	return String(enemy_overrides.get(ch, fallback))


## 그 위치의 이름 (구역 이름, 없으면 지역 이름)
func place_name(pos: Vector2) -> String:
	var z := zone_at_pos(pos)
	return z.display_name if z != null else display_name
