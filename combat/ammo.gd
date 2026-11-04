class_name Ammo
extends RefCounted
## 탄약. 자동 재장전 없음 — 근접 명중·패링으로만 회복한다.

var current: int = 0
var maximum: int = 0


func _init(max_value: int, start_value: int) -> void:
	maximum = max_value
	current = clampi(start_value, 0, maximum)


## 한 발 쓴다. 없으면 false
func consume() -> bool:
	if current <= 0:
		return false
	current -= 1
	_emit()
	return true


func add(amount: int) -> void:
	if amount <= 0:
		return
	current = mini(current + amount, maximum)
	_emit()


func set_current(value: int) -> void:
	current = clampi(value, 0, maximum)
	_emit()


func _emit() -> void:
	Events.ammo_changed.emit(current, maximum)
