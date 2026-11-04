class_name Hitbox
extends HitArea
## 공격 영역 (근접 베기 등). 적 탄이 이 영역에 닿으면 parry_handler 로 패링을 시도한다.

## func(projectile: Projectile) -> bool  (패링 성공 여부)
var parry_handler: Callable


func _init() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0


## 판정 켜기/끄기 (즉시 반영: 같은 틱 안의 탄 판정에 바로 쓰인다)
func set_active(value: bool) -> void:
	if shape_node:
		shape_node.disabled = not value


func is_active() -> bool:
	return shape_node != null and not shape_node.disabled


func try_parry(projectile: Projectile) -> bool:
	if not is_active() or not parry_handler.is_valid():
		return false
	return bool(parry_handler.call(projectile))
