class_name SkillData
extends Resource
## 스킬 공통 데이터. 실제 값은 res://data/skills/*.tres
## 스킬마다 하위 클래스(BlinkData 등) + Skill 하위 클래스를 짝으로 만든다.
## 본편에서 스킬을 늘리려면 data/skills 에 리소스를 추가하고 DB.skills 목록에 넣는다.
## 주의: description 에 숨은 테크를 쓰지 않는다.

## 저장·리더보드용 고유 이름 (영문)
@export var id: String = ""
@export var display_name: String = ""
## 성격 (이동·지름길 / 자원 / ...)
@export var tag: String = ""
@export_multiline var description: String = ""
## 스킬 선택 창에서 "추천" 표시
@export var recommended: bool = false
@export var cooldown_ticks: int = 0
## skill_icons 시트의 애니메이션 이름
@export var icon: StringName = &""


## 이 데이터로 스킬 동작 객체를 만든다 (하위 클래스에서 구현)
func create_skill() -> Skill:
	push_error("SkillData.create_skill() 를 하위 클래스에서 구현해야 함: %s" % id)
	return null
