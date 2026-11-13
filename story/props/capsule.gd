class_name Capsule
extends StaticBody2D
## 실험 캡슐 (맵 글자 'K' 멀쩡함 / 'k' 깨짐 — 주인공이 나온 것). 프롤로그(연구소 지하)의 장식. 지나갈 수 없다.

## 16×32 그림의 아래 칸이 이 칸에 오도록 위로 올리는 높이
const SPRITE_OFFSET := Vector2(0, -8)

var broken: bool = false


func setup_from_map(ch: String, _cell: Vector2i) -> void:
	broken = ch == "k"


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 12)
	shape.shape = rect
	add_child(shape)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = DB.theme.load_sheet("basement_props")
	sprite.play(&"capsule_broken" if broken else &"capsule")
	sprite.position = SPRITE_OFFSET
	add_child(sprite)
