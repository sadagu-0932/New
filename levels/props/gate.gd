class_name Gate
extends StaticBody2D
## 구간 출구의 문 (맵 글자 'G'). 구간 조건(적 전멸·스위치)이 채워지면 열린다.

var is_open: bool = false
var _shape: CollisionShape2D
var _sprite: AnimatedSprite2D


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2.ONE * LevelMap.TILE_SIZE
	_shape.shape = rect
	add_child(_shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = DB.theme.load_sheet("props")
	_sprite.play(&"gate_closed")
	add_child(_sprite)


func open() -> void:
	if is_open:
		return
	is_open = true
	_shape.disabled = true
	_sprite.play(&"gate_open")
