class_name BlinkSkill
extends Skill
## 블링크: 이동 방향(없으면 조준 방향)으로 짧게 순간이동. 순간이동이라 사이의 탄·구덩이를 지나친다.
## 벽은 못 뚫는다. 도착 지점이 벽·구덩이·적과 겹치면 겹치지 않는 곳까지 당겨서 도착.

const MAX_RESULTS := 4

var _invuln_left: int = 0
var _query := PhysicsShapeQueryParameters2D.new()


func _bd() -> BlinkData:
	return data as BlinkData


func grants_invulnerability() -> bool:
	return _invuln_left > 0


func _tick_effect() -> void:
	if _invuln_left > 0:
		_invuln_left -= 1


func _activate() -> bool:
	var d := _bd()
	var input := PlayerInput.current
	var dir := input.move if input.move != Vector2.ZERO else player.aim_dir
	dir = dir.normalized()
	var from := player.global_position
	var dest := _find_destination(from, dir, d.distance)
	if dest.distance_to(from) < d.min_distance:
		return false
	Effect.spawn(&"stealth_puff", from)
	player.teleport(dest)
	Effect.spawn(&"stealth_puff", dest)
	_invuln_left = d.invuln_ticks
	return true


## from 에서 dir 로 distance 까지 가면서, 벽을 넘지 않고 몸이 아무것과도 겹치지 않는 가장 먼 지점
func _find_destination(from: Vector2, dir: Vector2, distance: float) -> Vector2:
	var space := player.get_world_2d().direct_space_state
	var body_offset := Vector2(0, player.data.body_offset_y)
	# 벽 앞까지만
	var ray := PhysicsRayQueryParameters2D.create(from + body_offset, from + body_offset + dir * distance, Layers.WORLD, [player.get_rid()])
	var hit := space.intersect_ray(ray)
	var max_dist := distance
	if not hit.is_empty():
		max_dist = maxf((hit["position"] as Vector2 - (from + body_offset)).length() - player.data.body_radius, 0.0)
	var circle := CircleShape2D.new()
	circle.radius = player.data.body_radius
	_query.shape = circle
	_query.collision_mask = Layers.WORLD | Layers.PIT | Layers.ENEMY
	_query.exclude = [player.get_rid()]
	var step := _bd().search_step
	var dist := max_dist
	while dist > 0.0:
		var pos := from + dir * dist
		_query.transform = Transform2D(0.0, pos + body_offset)
		if space.intersect_shape(_query, MAX_RESULTS).is_empty():
			return pos
		dist -= step
	return from
