class_name ItemPickup
extends Node2D
## 획득물 (맵 글자 '$', 또는 코드로 떨어뜨린 것). 닿으면 인벤토리에 들어간다.
## 한 번 주운 것은 다시 나오지 않는다 (taken_flag 를 스토리 진행도에 기록).

var item_id: String = ""
var taken_flag: String = ""
var _sprite: AnimatedSprite2D


func _ready() -> void:
	if not taken_flag.is_empty() and Story.has_flag(taken_flag):
		queue_free()
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = DB.theme.load_sheet("story_props")
	var item := DB.item(item_id)
	_sprite.play(&"pickup_doc" if item != null and item.category == ItemData.Category.DOCUMENT else &"pickup")
	add_child(_sprite)


func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null or player.is_dead() or is_queued_for_deletion():
		return
	if player.global_position.distance_to(global_position) > DB.story.pickup_radius:
		return
	if not taken_flag.is_empty():
		Story.set_flag(taken_flag)
	Story.inventory.add(item_id)
	Events.item_picked.emit(item_id)
	queue_free()
