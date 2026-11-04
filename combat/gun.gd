class_name Gun
extends RefCounted
## 사격. 탄약이 0이면 쏘지 못한다.

var data: GunData
var _cooldown: int = 0


func _init(gun_data: GunData) -> void:
	data = gun_data


func tick_cooldown() -> void:
	if _cooldown > 0:
		_cooldown -= 1


func is_ready() -> bool:
	return _cooldown <= 0


## 쏘기 시도. 실제로 쐈으면 true
func try_fire(ammo: Ammo, container: Node, origin: Vector2, dir: Vector2) -> bool:
	if not is_ready() or container == null:
		return false
	if not ammo.consume():
		return false
	Projectile.spawn(container, Team.PLAYER, origin + dir * data.muzzle_offset, dir, data.projectile)
	_cooldown = data.fire_interval_ticks
	return true
