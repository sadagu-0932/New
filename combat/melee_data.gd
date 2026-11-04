class_name MeleeData
extends Resource
## 근접 공격 수치. 실제 값은 res://data/melee.tres

## 판정이 켜져 있는 틱
@export var active_ticks: int = 0
## 판정이 끝난 뒤 다시 휘두를 수 있을 때까지 틱
@export var recovery_ticks: int = 0
## 판정 원 중심 거리 (조준 방향, px)
@export var offset: float = 0.0
## 판정 원 반지름 (px)
@export var radius: float = 0.0
@export var damage: int = 0
## 휘두르는 동안 이동 속도 배율
@export var move_speed_mult: float = 1.0
## 적 하나를 맞힐 때마다 회복하는 탄약
@export var ammo_on_hit: int = 0
