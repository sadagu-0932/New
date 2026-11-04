class_name ProjectileData
extends Resource
## 탄 수치. 실제 값은 res://data/projectiles/*.tres

## 속도 (px/s)
@export var speed: float = 0.0
@export var damage: int = 0
## 판정 반지름 (px)
@export var radius: float = 0.0
## 사라질 때까지 틱
@export var lifetime_ticks: int = 0
## bullets 시트의 애니메이션 이름
@export var anim: StringName = &""
