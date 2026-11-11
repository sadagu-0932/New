class_name AreaExit
extends Node2D
## 지역 출입구 (맵 글자 'E'). 플레이어가 밟으면 Events.area_exit_entered. 그림은 없다 (맵의 길이 곧 출입구).
## 잠긴 출입구(required_flag)는 밟고 있는 동안 하단에 글을 보여준다.

var data: AreaExitData
var _inside: bool = false


func is_locked() -> bool:
	return data != null and not data.required_flag.is_empty() and not Story.has_flag(data.required_flag)


func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if data == null or player == null or player.is_dead() or player.cutscene_lock:
		return
	var now := player.global_position.distance_to(global_position) <= LevelMap.TILE_SIZE * 0.75
	if now == _inside:
		return
	_inside = now
	if not now:
		if is_locked():
			Events.hint_changed.emit("")
		return
	if is_locked():
		Events.hint_changed.emit(data.locked_text)
	else:
		Events.area_exit_entered.emit(data)
