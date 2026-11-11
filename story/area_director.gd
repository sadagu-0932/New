class_name AreaDirector
extends Node
## 스토리 지역 진행 관리 (레벨의 자식, 튜토리얼의 TutorialDirector 자리).
##  - 맵의 출입구·웨이스톤·획득물·NPC·표지판에 지역 데이터(AreaData)를 순서대로 짝지어 준다
##  - 처음 들어온 지역이면 들어오는 글을 흘려 보낸다

var level: Level
var area: AreaData


func _init(owner_level: Level, area_data: AreaData) -> void:
	level = owner_level
	area = area_data


## 소품이 _ready 되기 전에(트리에 붙기 전에) 데이터를 넣어 준다. Level 이 소품을 만들 때마다 부른다
func configure(node: Node, index: int) -> void:
	if node is AreaExit:
		(node as AreaExit).data = _at(area.exits, index) as AreaExitData
	elif node is Waystone:
		(node as Waystone).data = _at(area.waystones, index) as WaystoneData
	elif node is ItemPickup:
		var pickup := node as ItemPickup
		pickup.item_id = String(_at(area.pickups, index, ""))
		pickup.taken_flag = "pickup:%s:%d" % [area.id, index]
	elif node is Npc:
		(node as Npc).data = _at(area.npcs, index) as NpcData
	elif node is Signpost:
		var sign := node as Signpost
		sign.radius = DB.game_config.tutorial.sign_radius
		sign.text = String(_at(area.signs, index, ""))


static func _at(list: Array, index: int, fallback: Variant = null) -> Variant:
	if index < list.size():
		return list[index]
	push_warning("지역 데이터가 맵의 소품 수보다 적음 (index %d)" % index)
	return fallback


func _ready() -> void:
	Events.area_entered.emit(area.id)
	var seen_flag := "entered:%s" % area.id
	if not area.enter_story_id.is_empty() and not Story.has_flag(seen_flag):
		Events.story_triggered.emit(area.enter_story_id)
	Story.set_flag(seen_flag)


func _exit_tree() -> void:
	Events.hint_changed.emit("")
