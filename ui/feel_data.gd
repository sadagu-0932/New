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

@export_group("잔상 (회피·돌진 중)")
## 몇 틱마다 잔상을 남길지
@export var afterimage_interval_ticks: int = 0
## 잔상이 사라지는 시간 (초)
@export var afterimage_fade_seconds: float = 0.0
