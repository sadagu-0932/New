class_name BlinkData
extends SkillData
## 블링크 수치. 실제 값은 res://data/skills/blink.tres

## 최대 순간이동 거리 (px)
@export var distance: float = 0.0
## 이보다 짧게밖에 못 가면 발동 안 함 (쿨타임도 안 씀)
@export var min_distance: float = 0.0
## 도착 후 무적 틱
@export var invuln_ticks: int = 0
## 도착 지점을 찾을 때 뒤로 당기는 간격 (px)
@export var search_step: float = 0.0


func create_skill() -> Skill:
	return BlinkSkill.new(self)
