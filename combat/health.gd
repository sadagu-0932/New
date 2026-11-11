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


## 최대치 변경 (갑옷 장착 등). 현재값은 넘치지 않게만 맞춘다
func set_maximum(value: int) -> void:
	maximum = maxi(value, 1)
	current = mini(current, maximum)


func is_dead() -> bool:
	return current <= 0
