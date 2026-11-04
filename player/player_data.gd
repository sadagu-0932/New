class_name PlayerData
extends Resource
## 플레이어 수치. 실제 값은 res://data/player.tres

## 이동 속도 (px/s)
@export var move_speed: float = 0.0
## 벽 충돌 원 반지름·발밑 오프셋 (탑다운이라 발 쪽에 작게)
@export var body_radius: float = 0.0
@export var body_offset_y: float = 0.0
## 피격 원 반지름·오프셋
@export var hurtbox_radius: float = 0.0
@export var hurtbox_offset_y: float = 0.0
## 체력 (칸)
@export var max_hp: int = 0
## 피격 후 무적 틱
@export var hurt_invuln_ticks: int = 0
