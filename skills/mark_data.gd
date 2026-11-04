class_name MarkData
extends SkillData
## 표식 수치. 실제 값은 res://data/skills/mark.tres

## 표식을 걸 수 있는 거리 (px)
@export var mark_range: float = 0.0
## 표식 유지 틱
@export var duration_ticks: int = 0
## 표식된 적이 받는 데미지 배율 (올림)
@export var damage_mult: float = 1.0


func create_skill() -> Skill:
	return MarkSkill.new(self)
