class_name CombatState
extends RefCounted
## 스토리판의 "전투 중" 판정. 전투 중에는 스킬 변경·저장·순간이동을 막는다.
## - 깨어난 보스가 살아 있으면 전투 중 (보스방)
## - 플레이어를 본 적이 일정 거리(data/story.tres 의 combat_radius) 안에 살아 있으면 전투 중


## 저장·순간이동·장착 변경을 막아야 하는지: 전투 중이거나, 보스를 쓰러뜨리기 전의 보스방
static func is_restricted(tree: SceneTree) -> bool:
	var area := DB.area(Story.area)
	var player := tree.get_first_node_in_group(Player.GROUP) as Node2D
	if Game.is_story_mode() and area != null and player != null:
		if area.in_boss_room(player.global_position):
			return true
	return in_combat(tree)


static func in_combat(tree: SceneTree) -> bool:
	var player := tree.get_first_node_in_group(Player.GROUP) as Node2D
	if player == null:
		return false
	var radius := DB.story.combat_radius
	for node in tree.get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e == null or e.dead:
			continue
		var golem := e as Golem
		if golem != null:
			if golem.is_fighting():
				return true
			continue
		if e.has_target and e.global_position.distance_to(player.global_position) <= radius:
			return true
	return false
