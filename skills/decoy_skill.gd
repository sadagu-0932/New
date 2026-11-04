class_name DecoySkill
extends Skill
## 미끼 분신: 지금 자리에 분신을 남긴다. 적은 분신이 보이면 분신을 노린다.
## 분신은 한 번에 하나 (새로 쓰면 이전 분신은 사라짐).

var _decoy: Decoy


func _dd() -> DecoyData:
	return data as DecoyData


func _activate() -> bool:
	cleanup()
	var level := player.get_parent()
	_decoy = Decoy.new()
	_decoy.data = _dd()
	_decoy.position = player.global_position
	# 소품·적보다 먼저 처리되도록 레벨의 소품 노드 안에 둔다
	var props: Node = level.get_node_or_null("Props")
	(props if props else level).add_child(_decoy)
	Effect.spawn(&"stealth_puff", player.global_position)
	return true


func cleanup() -> void:
	if is_instance_valid(_decoy):
		_decoy.vanish()
	_decoy = null
