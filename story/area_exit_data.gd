class_name AreaExitData
extends Resource
## 지역 출입구 하나 (맵 글자 'E', 맵에서 읽는 순서대로 AreaData.exits 와 짝지어진다).

## 넘어갈 지역 id. "" 이면 이번 작업 범위의 끝 (end_text 를 보여주고 타이틀로)
@export var target_area: String = ""
## 도착 지점: 0 = 그 지역의 P, 1~7 = 그 지역 맵의 숫자 칸
@export var target_spawn: int = 0
## 이 스토리 진행도가 있어야 지나갈 수 있다 ("" = 항상 열림)
@export var required_flag: String = ""
## 잠겨 있을 때 하단에 보이는 글
@export var locked_text: String = ""
## target_area 가 "" 일 때 보여줄 글
@export_multiline var end_text: String = ""
