class_name Health
extends RefCounted
## 체력 (칸 단위 정수)

var current: int = 0
var maximum: int = 0


func _init(max_value: int) -> void:
	maximum = max_value
	current = max_value


## 데미지를 받고 남은 체력을 돌려준다
func damage(amount: int) -> int:
	current = maxi(current - amount, 0)
	return current


func heal(amount: int) -> void:
	current = mini(current + amount, maximum)


func is_dead() -> bool:
	return current <= 0
