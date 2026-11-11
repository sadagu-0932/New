class_name TouchData
extends Resource
## 안드로이드 터치 조작 수치·배치 (화면 좌표는 320x180 기준)

@export_group("조이스틱")
## 왼쪽 이동 조이스틱 중심
@export var move_stick_center: Vector2 = Vector2.ZERO
## 오른쪽 조준·사격 조이스틱 중심
@export var aim_stick_center: Vector2 = Vector2.ZERO
## 손잡이가 움직일 수 있는 최대 거리 (px)
@export var stick_radius: float = 0.0
## 조이스틱을 잡을 수 있는 범위 (중심에서 이 거리 안을 처음 누르면 잡힘)
@export var stick_grab_radius: float = 0.0
## 이 비율 미만으로 밀면 0 (손가락 떨림 무시)
@export var stick_deadzone: float = 0.0
## 조준 조이스틱을 이 비율 이상 밀면 사격
@export var aim_fire_threshold: float = 0.0
## 조준점이 플레이어에서 떨어진 거리 (px)
@export var aim_distance: float = 0.0
## 이동 조이스틱을 이 비율 이상 밀면 메뉴에서 방향 입력으로 친다
@export var menu_direction_threshold: float = 0.0

@export_group("버튼")
## 오른쪽 둥근 버튼 위치 (근접, 회피, 스킬1, 사용, 스킬2 순)
@export var action_button_positions: Array[Vector2] = []
## 둥근 버튼을 누를 수 있는 반지름 (그림보다 살짝 크게)
@export var action_button_radius: float = 0.0
## 위쪽 작은 버튼 위치 (일시정지, 재시작, 스킬 설정 순)
@export var top_button_positions: Array[Vector2] = []
## 메뉴용 버튼 위치 (확인, 뒤로 순)
@export var menu_button_positions: Array[Vector2] = []
## 일시정지 화면의 [배치] 버튼 위치
@export var pause_button_position: Vector2 = Vector2.ZERO
## 배치 모드의 버튼 위치 (완료, 초기화 순)
@export var edit_button_positions: Array[Vector2] = []

@export_group("모양")
## 평소 투명도
@export var idle_alpha: float = 0.0
## 누르고 있을 때 투명도
@export var pressed_alpha: float = 0.0
## 아직 잠긴 버튼(스킬2) 투명도
@export var locked_alpha: float = 0.0

@export_group("안내 글 바꾸기")
## 안내 글에서 찾을 키보드·마우스 말 → 대신 넣을 터치 버튼 말 (위에서부터 차례로, 긴 말부터)
@export var text_map: Dictionary = {}
