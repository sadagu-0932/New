class_name AbsorbData
extends SkillData
## 흡수 장막 수치. 실제 값은 res://data/skills/absorb.tres

## 장막 유지 틱
@export var duration_ticks: int = 0
## 장막 원 중심 거리 (조준 방향, px)·반지름
@export var offset: float = 0.0
@export var radius: float = 0.0
## 탄 하나를 흡수할 때 얻는 탄약
@export var ammo_per_bullet: int = 0
## 장막 그림 크기 배율 (화면 표시)
@export var sprite_scale: float = 1.0


func create_skill() -> Skill:
	return AbsorbSkill.new(self)
