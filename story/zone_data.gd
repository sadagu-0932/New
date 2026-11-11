class_name ZoneData
extends Resource
## 구역: 이어진 한 장의 세계(AreaData) 안에서 이름이 붙은 네모 영역 (연구소, 광산촌, 숲 …).
## 화면이 바뀌지 않고 걸어서 드나든다. 구역마다 타일 그림·적 수치·규칙이 다를 수 있다.
## 어느 구역에도 들지 않는 땅은 AreaData 자체의 설정(들판)을 따른다.

@export var id: String = ""
@export var display_name: String = ""
## 맵에서 차지하는 네모 (칸)
@export var rect: Rect2i = Rect2i()
## 타일 그림 (art 테마의 시트 이름)
@export var tileset: String = "tiles"
## 벽(나무)을 근접 공격으로 베어 지나갈 수 있는지
@export var breakable_walls: bool = false
## 보스방: 보스를 쓰러뜨리기(boss_cleared_flag) 전에는 이 안에서 저장·순간이동 불가
@export var is_boss_room: bool = false
@export var boss_cleared_flag: String = ""
## 처음 들어왔을 때 흘러가는 글 (data/story.tres 의 lines 키, "" = 없음)
@export var enter_story_id: String = ""
## 맵 글자 → 적 데이터 이름 (data/enemies/ 의 파일 이름). 없는 글자는 기본 적
@export var enemy_overrides: Dictionary = {}
## 지도에서의 지형 색 (바닥 / 벽·나무·집)
@export var map_floor_color: Color = Color(0.56, 0.52, 0.62)
@export var map_wall_color: Color = Color(0.24, 0.21, 0.3)


## 보스방 제한이 걸려 있는지
func is_restricted() -> bool:
	return is_boss_room and not Story.has_flag(boss_cleared_flag)
