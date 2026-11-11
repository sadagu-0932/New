class_name Waystone
extends Node2D
## 웨이스톤 (맵 글자 'Y'). 닿으면 활성화된다 → Events.waystone_touched (회복·지도·자동저장은 StoryMain).

var data: WaystoneData
var active: bool = false
var _sprite: AnimatedSprite2D


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = DB.theme.load_sheet("story_props")
	add_child(_sprite)
	refresh()


func refresh() -> void:
	active = data != null and Story.waystones.has(data.id)
	if _sprite:
		_sprite.play(&"waystone_on" if active else &"waystone_off")


func _physics_process(_delta: float) -> void:
	if active or data == null:
		return
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null or player.is_dead():
		return
	if player.global_position.distance_to(global_position) <= DB.story.waystone_radius:
		Events.waystone_touched.emit(self)
