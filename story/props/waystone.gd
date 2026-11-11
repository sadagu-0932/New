class_name Waystone
extends StaticBody2D
## 웨이스톤 (맵 글자 'Y'). 돌탑 모양이며 닿으면 활성화된다 → Events.waystone_touched (회복·지도·자동저장은 StoryMain).
## 활성화하면 꼭대기 마석에 불이 들어오고, 그 주변이 지도에서 밝혀진다.

## 탑 그림을 발밑(칸 중심)에서 위로 올리는 높이 (16×32 그림의 아래 칸이 이 칸에 오도록)
const SPRITE_OFFSET := Vector2(0, -8)

var data: WaystoneData
var active: bool = false
var _sprite: AnimatedSprite2D


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = DB.theme.load_sheet("waystone")
	_sprite.position = SPRITE_OFFSET
	add_child(_sprite)
	refresh()


func refresh() -> void:
	active = data != null and Story.waystones.has(data.id)
	if _sprite:
		_sprite.play(&"on" if active else &"off")


func _physics_process(_delta: float) -> void:
	if active or data == null:
		return
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null or player.is_dead():
		return
	if player.global_position.distance_to(global_position) <= DB.story.waystone_radius:
		Events.waystone_touched.emit(self)
