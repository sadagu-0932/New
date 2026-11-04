class_name TutorialSectionData
extends Resource
## 튜토리얼 구간 하나의 설정. res://data/tutorial.tres 안에 7개가 들어 있다.
## 주의: 숨은 테크는 hint 에 절대 쓰지 않는다.

enum GateRule {
	NONE,    ## 문 없음 / 항상 열림
	CLEAR,   ## 구간의 적을 모두 처치하면 열림
	SWITCH,  ## 구간의 수정 스위치를 모두 켜면 열림 (적은 남아 있어도 됨)
}

## 구간 맵 파일 (글자 맵). 모든 구간은 높이가 같아야 하고, 마지막 열이 오른쪽 벽(출구)이다
@export_file("*.txt") var map_file: String = ""
## 화면 하단 안내 문구 (빈 문자열 = 없음)
@export_multiline var hint: String = ""
## 이 행동을 하면 안내 문구가 사라진다 ("", dodge, shoot, melee, parry, perfect_dodge, skill)
@export var hint_hide_on: String = ""
## 행동 후 문구가 사라질 때까지 틱
@export var hint_hide_delay_ticks: int = 0
## 입장하면 탄약을 0으로 만든다 (근접 구간)
@export var drain_ammo: bool = false
@export var gate_rule: GateRule = GateRule.NONE
## 이 구간 표지판(맵 글자 'I')에 쓸 글
@export_multiline var sign_text: String = ""
## 본편에서 연결할 스토리 트리거 ID
@export var story_id: String = ""
