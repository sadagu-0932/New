class_name AreaDirector
extends Node
## 스토리 지역 진행 관리 (레벨의 자식, 튜토리얼의 TutorialDirector 자리).
##  - 맵의 출입구·웨이스톤·획득물·NPC·표지판에 지역 데이터(AreaData)를 순서대로 짝지어 준다
##  - 플레이어가 어느 구역(연구소·광산촌·숲 …)에 있는지 지켜보고, 구역에 들어서면 이름을 보여준다.
##    처음 들어선 구역이면 들어오는 글을 흘려 보낸다

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


## 플레이어가 지금 든 구역 id ("" = 들판, "?" = 아직 모름)
var zone_id: String = "?"
## 전투 밖에서 재장전까지 남은 틱
var reload_ticks: int = -1


func _physics_process(_delta: float) -> void:
	var player := level.player
	if player == null:
		return
	_tick_reload(player)
	var zone := area.zone_at_pos(player.global_position)
	var now := zone.id if zone != null else ""
	if now == zone_id:
		return
	var first_tick := zone_id == "?"
	zone_id = now
	Events.zone_entered.emit(now)
	if zone == null or zone.display_name.is_empty():
		return  # 이름 없는 미지의 땅
	# 지역에 걸어 들어오면 이름을 잠깐 보여주고, 처음이면 글이 흘러간다
	if not first_tick:
		Events.toast.emit(zone.display_name)
	var seen_flag := "entered:%s" % zone.id
	if not zone.enter_story_id.is_empty() and not Story.has_flag(seen_flag):
		Events.story_triggered.emit(zone.enter_story_id)
	Story.set_flag(seen_flag)


## 전투 중이 아니면 일정 시간마다 탄창을 가득 채운다 (data/story.tres 의 auto_reload_seconds)
func _tick_reload(player: Player) -> void:
	var interval := int(DB.story.auto_reload_seconds * Game.config.tick_rate)
	if interval <= 0 or player.is_dead():
		return
	if reload_ticks < 0 or CombatState.in_combat(get_tree()):
		reload_ticks = interval      # 전투 중이면 처음부터 다시 센다
		return
	reload_ticks -= 1
	if reload_ticks > 0:
		return
	reload_ticks = interval
	if player.ammo.current < player.ammo.maximum:
		player.ammo.set_current(player.ammo.maximum)
		Events.toast.emit(DB.story.text_reloaded)
		Audio.play("ui_confirm")


func _exit_tree() -> void:
	Events.hint_changed.emit("")
