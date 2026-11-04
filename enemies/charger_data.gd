class_name ChargerData
extends EnemyData
## 돌진형 수치. 실제 값은 res://data/enemies/charger*.tres

## 플레이어가 이 거리 안이면 돌진 준비
@export var charge_trigger_range: float = 0.0
## 돌진 준비(예고) 틱
@export var windup_ticks: int = 0
## 돌진 속도 (px/s)·틱
@export var charge_speed: float = 0.0
@export var charge_ticks: int = 0
## 돌진 후 멈춰 있는 틱 (반격 기회)
@export var recover_ticks: int = 0
