class_name MarkSkill
extends Skill
## 표식: 조준점에 가장 가까운 적(사거리 안, 벽에 가리지 않음)에 표식. 표식된 적은 받는 데미지 증가.
## 쿨타임이 짧다. 대상이 없으면 발동하지 않는다 (쿨타임도 안 씀).


func _md() -> MarkData:
	return data as MarkData


func _activate() -> bool:
	var d := _md()
	var aim := PlayerInput.current.aim
	var best: Enemy = null
	var best_d := INF
	var space := player.get_world_2d().direct_space_state
	for node in player.get_tree().get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e == null or e.dead:
			continue
		if e.global_position.distance_to(player.global_position) > d.mark_range:
			continue
		var ray := PhysicsRayQueryParameters2D.create(player.global_position, e.global_position, Layers.WORLD)
		if not space.intersect_ray(ray).is_empty():
			continue
		var da := e.global_position.distance_to(aim)
		# 같은 거리면 위치 순 (결정론)
		if da < best_d or (da == best_d and best != null and e.global_position.x < best.global_position.x):
			best = e
			best_d = da
	if best == null:
		return false
	best.apply_mark(d.duration_ticks, d.damage_mult)
	return true
