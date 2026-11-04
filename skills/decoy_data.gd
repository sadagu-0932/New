class_name DecoyData
extends SkillData
## 미끼 분신 수치. 실제 값은 res://data/skills/decoy.tres

## 분신 유지 틱
@export var duration_ticks: int = 0
## 분신이 버티는 데미지
@export var hp: int = 0


func create_skill() -> Skill:
	return DecoySkill.new(self)
