class_name DashDodgeData
extends DodgeData
## 대시형 회피 수치. 실제 값은 res://data/dodge.tres

## 대시 속도 (px/s)
@export var speed: float = 0.0
## 대시 지속 틱
@export var duration_ticks: int = 0
## 시작부터 무적인 틱 수
@export var invuln_ticks: int = 0
## 대시가 끝난 뒤 다시 쓸 수 있을 때까지 틱
@export var cooldown_ticks: int = 0


func create_ability() -> DodgeAbility:
	return DashDodge.new(self)
