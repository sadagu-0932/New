class_name Rubble
extends StaticBody2D
## 잔해 (맵 글자 'R'). 길을 막는 장식 — 골렘이 부수고 지나간 흔적.


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2.ONE * LevelMap.TILE_SIZE
	shape.shape = rect
	add_child(shape)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = DB.theme.load_sheet("story_props")
	# 칸 좌표로 모양을 고른다 (게임 RNG 를 쓰지 않음)
	var cell := Vector2i(position / LevelMap.TILE_SIZE)
	sprite.play(&"rubble_b" if (cell.x * 3 + cell.y * 5) % 2 == 0 else &"rubble_a")
	add_child(sprite)
