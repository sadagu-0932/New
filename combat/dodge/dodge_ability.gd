class_name DodgeAbility
extends RefCounted
## 회피 동작 베이스. 플레이어는 이 인터페이스만 쓴다.
## 매 틱 순서: tick_cooldown() → (회피 중이면) tick() 로 이번 틱 속도를 받는다.


## 회피 중인지
func is_active() -> bool:
	return false


## 지금 무적인지
func is_invulnerable() -> bool:
	return false


## 새 회피를 시작할 수 있는지 (쿨타임 포함)
func can_start() -> bool:
	return false


## 회피 시작. direction 은 길이 1
func start(_direction: Vector2) -> void:
	pass


## 회피 중 한 틱 진행, 이번 틱 이동 속도(px/s)를 돌려준다
func tick() -> Vector2:
	return Vector2.ZERO


## 회피 중이 아닐 때 쿨타임을 줄인다
func tick_cooldown() -> void:
	pass


## 이번 회피가 시작된 뒤 지난 틱 수 (완벽 회피 판정용, M2)
func elapsed_ticks() -> int:
	return 0


## 이번 회피의 방향
func direction() -> Vector2:
	return Vector2.ZERO
