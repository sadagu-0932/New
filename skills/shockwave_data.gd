class_name ShockwaveData
extends SkillData
## 충격파 수치. 실제 값은 res://data/skills/shockwave.tres

## 범위 반지름 (px)
@export var radius: float = 0.0
## 적 밀쳐내기 속도 (px/s)·틱
@export var knockback_speed: float = 0.0
@export var knockback_ticks: int = 0
## 적에게 주는 데미지 (0 = 없음)
@export var damage: int = 0


func create_skill() -> Skill:
	return ShockwaveSkill.new(self)
