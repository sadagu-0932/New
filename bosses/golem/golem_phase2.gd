class_name GolemPhase2
extends GolemPhase1
## 2페이즈 (본편용 자리). 데모(DEMO_MODE)에서는 컷씬에서 주인공이 쓰러지며 끝나므로 쓰지 않는다.
## TODO(본편): 2페이즈 전용 패턴·실제 전투. 지금은 1페이즈 패턴을 더 빠르게 쓰는 임시 구현.


func number() -> int:
	return 2


func enter() -> void:
	speed_mult = golem.gd().phase2_speed_mult
	super.enter()
