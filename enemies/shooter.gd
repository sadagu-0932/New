class_name Shooter
extends Enemy
## 원거리형: 거리를 유지하며 플레이어에게 느린 탄을 쏜다. 패링 연습용.
## 플레이어를 놓치면 쏘지 않고 마지막으로 본 위치로 간다.

var _fire_timer: int = -1


func _sd() -> ShooterData:
	return data as ShooterData


func _tick_ai() -> void:
	var d := _sd()
	if not has_target:
		velocity = Vector2.ZERO
		return
	if not sees_player:
		move_to(target_pos, d.move_speed)
		return
	if _fire_timer < 0:
		_fire_timer = d.first_shot_delay_ticks
	var dist := global_position.distance_to(target_pos)
	if dist > d.keep_max:
		move_to(target_pos, d.move_speed)
	elif dist < d.keep_min:
		velocity = -dir_to_target() * d.move_speed
	else:
		velocity = Vector2.ZERO
	_fire_timer -= 1
	if _fire_timer <= 0:
		_fire_timer = d.fire_interval_ticks
		var dir := dir_to_target()
		var container := get_tree().get_first_node_in_group(Level.GROUP_PROJECTILES)
		if container:
			Projectile.spawn(container, Team.ENEMY, global_position + dir * d.muzzle_offset, dir, d.projectile)


func _anim() -> StringName:
	if sees_player and _fire_timer >= 0 and _fire_timer <= _sd().telegraph_ticks:
		return &"attack"
	return super._anim()
