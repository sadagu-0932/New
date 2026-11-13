class_name StoryData
extends Resource
## 스토리판 공통 설정·글. 실제 값은 res://data/story.tres
## 숨은 테크는 여기 글에도 절대 넣지 않는다.

## 타이틀 화면의 부제
@export var title_subtitle: String = ""
## 프롤로그(연구소 지하) 맵. 스피드런판 튜토리얼과 따로 둔다 (기술을 자연스럽게 익히게 다시 짠 것)
@export var prologue: TutorialData
## 골렘에게 쓰러진 뒤: 화면이 어두워진 채 머무는 시간 → 같은 자리에서 깨어나며 밝아지는 시간 (초, 글자 없음)
@export var prologue_dark_seconds: float = 0.0
@export var prologue_wake_seconds: float = 0.0
## 사다리를 오를 때 어두워지는 시간 / 바깥 세상에서 밝아지는 시간 (초)
@export var ladder_fade_out_seconds: float = 0.0
@export var ladder_fade_in_seconds: float = 0.0
## 사다리 앞 표시 (%s = 상호작용 키 이름)
@export var text_climb: String = ""
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
## 지도 화면을 처음 열 때 맵 한 칸의 크기 (px)
@export var map_tile_px: int = 1
## 지도 확대 단계들 (한 칸 px). 이보다 작은 "전체 보기" 단계가 맨 앞에 자동으로 붙는다
@export var map_zoom_levels: Array[float] = []
## 지도에서 맵 한 칸이 이 크기(px) 이상일 때 작은 지역 이름이 나온다 (그보다 작게 보면 묶음 이름만)
@export var map_area_names_px: float = 0.0
## 지도를 밝히는 원: 탑 하나가 밝히는 반지름, 처음에 연구소 둘레를 밝히는 반지름, 가장자리가 흐려지는 폭 (칸)
@export var map_reveal_radius: float = 0.0
@export var map_start_radius: float = 0.0
@export var map_reveal_fade: float = 0.0
## 지도에서 가리키는 곳(마우스)이 지명에 이 거리(px) 안으로 오면 그 지명이 뜬다
@export var map_label_radius_px: float = 0.0
## 지도에 꽂을 수 있는 핀 수, 다 찼을 때의 글 (%d = 핀 수)
@export var map_max_pins: int = 0
@export var text_pins_full: String = ""
## 바깥 세상에서 전투 중이 아니면 이 시간(초)마다 탄창을 가득 채운다 (0 = 끔)
@export var auto_reload_seconds: float = 0.0
@export var text_reloaded: String = ""
## 이 자료를 읽으면 그 글이 다 흘러간 뒤(ending_delay_seconds) 끝 글을 보여주고 타이틀로
@export var ending_document: String = ""
@export var ending_delay_seconds: float = 0.0
@export_multiline var ending_text: String = ""
## 이번 범위의 끝 글(AreaExitData.end_text)이 떠 있는 시간 (초). 그 뒤 타이틀로
@export var end_seconds: float = 0.0
