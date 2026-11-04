class_name GolemPhase
extends RefCounted
## 골렘 페이즈 상태 베이스. 본편에서 2페이즈 실제 전투를 이 구조에 추가한다.

var golem: Golem


func _init(owner_golem: Golem) -> void:
	golem = owner_golem


## 페이즈 번호
func number() -> int:
	return 0


func enter() -> void:
	pass


## 매 틱 (골렘이 그로기·컷씬이 아닐 때)
func tick() -> void:
	pass


## 지금 공격 예고 모션을 보여줄지
func is_attacking() -> bool:
	return false
