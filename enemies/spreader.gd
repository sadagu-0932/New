class_name Spreader
extends Enemy
## 탄막형: 천천히 다가오며 사방으로 탄을 원형으로 뿌린다 (발사마다 조금씩 회전).
## 완벽 회피·투명 체험용. 플레이어를 놓치면 쏘지 않고 마지막으로 본 위치로 간다.

var _fire_timer: int = -1
var _angle_deg: float = 0.0


func _pd() -> SpreaderData:
	return data as SpreaderData


func _tick_ai() -> void:
	var d := _pd()
	if not has_target:
		velocity = Vector2.ZERO
		return
	move_to(target_pos, d.move_speed)
	if not sees_player:
		return
	if _fire_timer < 0:
		_fire_timer = d.first_shot_delay_ticks
	_fire_timer -= 1
	if _fire_timer <= 0:
		_fire_timer = d.fire_interval_ticks
		_fire_volley(d)


func _fire_volley(d: SpreaderData) -> void:
	var container := get_tree().get_first_node_in_group(Level.GROUP_PROJECTILES)
	if container == null or d.bullets_per_volley <= 0:
		return
	var step := TAU / d.bullets_per_volley
	for i in d.bullets_per_volley:
		var dir := Vector2.RIGHT.rotated(deg_to_rad(_angle_deg) + step * i)
		Projectile.spawn(container, Team.ENEMY, global_position + dir * d.muzzle_offset, dir, d.projectile)
	_angle_deg = fmod(_angle_deg + d.rotation_step_deg, 360.0)


func _anim() -> StringName:
	if sees_player and _fire_timer >= 0 and _fire_timer <= _pd().telegraph_ticks:
		return &"attack"
	return super._anim()
