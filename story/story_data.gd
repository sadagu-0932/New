class_name StoryData
extends Resource
## 스토리판 공통 설정·글. 실제 값은 res://data/story.tres
## 숨은 테크는 여기 글에도 절대 넣지 않는다.

## 타이틀 화면의 부제
@export var title_subtitle: String = ""
## 프롤로그 끝 컷씬의 암전 글 ("TO BE CONTINUED" 자리)
@export var prologue_end_text: String = ""
## 스토리 트리거 id → 화면 위쪽에 차례로 흘러가는 글 (Array[String]). 게임을 멈추지 않는다
@export var lines: Dictionary = {}
## 글 한 줄이 떠 있는 틱
@export var line_ticks: int = 0
## 전투 중 판정: 플레이어를 본 적이 이 거리(px) 안에 살아 있으면 전투 중
@export var combat_radius: float = 0.0
## 전투 중이라 스킬 창을 못 열 때 잠깐 보여주는 글
@export_multiline var skill_locked_notice: String = ""
## 프롤로그가 끝난 뒤 깨어나는 지역 id
@export var after_prologue_area: String = ""
## 웨이스톤에 닿았다고 보는 거리 / 획득물을 줍는 거리 / NPC 에게 말을 걸 수 있는 거리 (px)
@export var waystone_radius: float = 0.0
@export var pickup_radius: float = 0.0
@export var talk_radius: float = 0.0
## 대화가 끝난 뒤 이 틱 동안은 다시 말을 걸지 않는다 (대사를 넘긴 키 입력이 곧바로 다시 말을 걸지 않게)
@export var talk_cooldown_ticks: int = 0
## %s = 지도 키 이름
@export var text_waystone_activated: String = ""
@export var text_item_picked: String = ""
@export var text_cannot_teleport: String = ""
@export var text_no_waystone: String = ""
## 지도 화면에서 맵 한 칸의 크기 (px)
@export var map_tile_px: int = 1
## 지도에서 아직 밝혀지지 않은 지역의 이름
@export var text_unknown_area: String = ""
## 이번 범위의 끝 글(AreaExitData.end_text)이 떠 있는 시간 (초). 그 뒤 타이틀로
@export var end_seconds: float = 0.0
