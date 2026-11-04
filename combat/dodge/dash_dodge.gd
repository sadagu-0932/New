class_name DashDodge
extends DodgeAbility
## 대시형 회피: 정해진 방향으로 일정 속도로 짧게 이동, 시작 구간 무적.

var _data: DashDodgeData
var _active: bool = false
var _elapsed: int = 0
var _cooldown_left: int = 0
var _direction: Vector2 = Vector2.RIGHT


func _init(data: DashDodgeData) -> void:
	_data = data


func is_active() -> bool:
	return _active


func is_invulnerable() -> bool:
	return _active and _elapsed < _data.invuln_ticks


func can_start() -> bool:
	return not _active and _cooldown_left <= 0


func start(dir: Vector2) -> void:
	_active = true
	_elapsed = 0
	_direction = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT


func tick() -> Vector2:
	if not _active:
		return Vector2.ZERO
	_elapsed += 1
	if _elapsed >= _data.duration_ticks:
		_active = false
		_cooldown_left = _data.cooldown_ticks
	return _direction * _data.speed


func tick_cooldown() -> void:
	if not _active and _cooldown_left > 0:
		_cooldown_left -= 1


func elapsed_ticks() -> int:
	return _elapsed


func direction() -> Vector2:
	return _direction
