class_name FeelData
extends Resource
## 화면 연출 수치 (화면 흔들림·번쩍임·잔상). 게임 로직·기록에는 영향 없음.
## 실제 값은 res://data/feel.tres

@export_group("화면 흔들림 (세기 px, 시간 초)")
@export var shake_hit: Vector2 = Vector2.ZERO
@export var shake_perfect: Vector2 = Vector2.ZERO
@export var shake_execute: Vector2 = Vector2.ZERO
@export var shake_groggy: Vector2 = Vector2.ZERO
@export var shake_enemy_death: Vector2 = Vector2.ZERO

@export_group("화면 번쩍임 (불투명도, 시간 초)")
@export var flash_perfect: Vector2 = Vector2.ZERO
@export var flash_hit: Vector2 = Vector2.ZERO

@export_group("망토 (움직임에 따라 휘날림, 화면 표시만)")
## 스프링 세기: 클수록 빨리 따라감
@export var cloak_stiffness: float = 0.0
## 감쇠: 클수록 덜 출렁임 (0~1)
@export var cloak_damping: float = 0.0
## 이동 속도(달리기 = 1)일 때 목표 기울기 (0 늘어짐 ~ 3 펄럭)
@export var cloak_run_lean: float = 0.0
## 위아래로 움직일 때 반영 비율
@export var cloak_vertical_factor: float = 0.0
## 회피·돌진 중 목표 기울기
@export var cloak_dodge_lean: float = 0.0
## 뒤로 걸을 때(조준 반대 방향) 몸 쪽으로 눌리는 정도
@export var cloak_backpedal_lean: float = 0.0

@export_group("플레이어 그림 방향 (화면 표시만)")
## 조준이 세로로 이 배율 이상 기울면 정면/뒷모습 (|y| > |x| × 값)
@export var view_switch_ratio: float = 0.0
## 방향이 바뀌는 경계에서 지금 그림을 유지하는 여유 (0.2 = 20%)
@export var view_hysteresis: float = 0.0

@export_group("탄 꼬리")
## 탄 꼬리 잔상이 사라지는 시간 (초)
@export var bullet_trail_fade_seconds: float = 0.0

@export_group("잔상 (회피·돌진 중)")
## 몇 틱마다 잔상을 남길지
@export var afterimage_interval_ticks: int = 0
## 잔상이 사라지는 시간 (초)
@export var afterimage_fade_seconds: float = 0.0
