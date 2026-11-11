class_name AreaData
extends Resource
## 지역 하나 (맵 하나). res://data/areas/ 아래에 .tres 를 넣으면 자동으로 등록된다.
## 맵 글자 중 스토리용: E 출입구 · Y 웨이스톤 · $ 획득물 · N NPC · I 표지판 · R 잔해(막힘)
## 같은 글자가 여러 개면 맵에서 읽는 순서(위→아래, 왼→오른)대로 아래 목록과 짝지어진다.
## 적은 새로 만들지 않고 기존 글자(C c S B Z)를 쓰며, 지역별 차이는 enemy_overrides 의 수치 데이터로만 낸다.

@export var id: String = ""
@export var display_name: String = ""
## 글자 맵 파일. 비어 있으면 튜토리얼(프롤로그) 맵을 쓴다
@export_file("*.txt") var map_file: String = ""
## 타일 그림 (art 테마의 시트 이름)
@export var tileset: String = "tiles"
## 지도 화면에 나오는지, 나온다면 넓은 지도의 어디에 (칸 단위, 지역 맵의 왼쪽 위 칸이 놓일 자리)
@export var on_map: bool = true
@export var map_pos: Vector2i = Vector2i.ZERO
## 지도에서의 지형 색 (바닥 / 벽·나무·집)
@export var map_floor_color: Color = Color(0.56, 0.52, 0.62)
@export var map_wall_color: Color = Color(0.24, 0.21, 0.3)
## 벽(나무)을 근접 공격으로 베어 지나갈 수 있는지, 몇 번 쳐야 베어지는지, 벨 때마다 얻는 아이템 id ("" = 없음)
@export var breakable_walls: bool = false
@export var break_hits: int = 0
@export var break_drop_item: String = ""
## 보스방: 보스를 쓰러뜨리기(boss_cleared_flag) 전에는 저장·순간이동 불가
@export var is_boss_room: bool = false
@export var boss_cleared_flag: String = ""
## 처음 들어왔을 때 흘러가는 글 (data/story.tres 의 lines 키, "" = 없음)
@export var enter_story_id: String = ""
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


## 보스방 제한이 걸려 있는지
func is_restricted() -> bool:
	return is_boss_room and not Story.has_flag(boss_cleared_flag)
