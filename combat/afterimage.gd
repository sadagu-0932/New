class_name AfterImage
extends Sprite2D
## 회피·돌진 잔상 (화면 표시 전용). 잠깐 남았다가 사라진다.

var _fade: float = 0.0
var _left: float = 0.0


static func spawn(texture_value: Texture2D, pos: Vector2, flip: bool, fade_seconds: float, tint: Color,
		rot: float = 0.0, scale_value: Vector2 = Vector2.ONE) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var container: Node = tree.get_first_node_in_group(Effect.GROUP)
	if container == null or texture_value == null:
		return
	var a := AfterImage.new()
	a.texture = texture_value
	a.position = pos
	a.flip_h = flip
	a.rotation = rot
	a.scale = scale_value
	a.modulate = tint
	a._fade = fade_seconds
	a._left = fade_seconds
	container.add_child(a)


func _process(delta: float) -> void:
	_left -= delta
	modulate.a = 0.5 * maxf(_left, 0.0) / maxf(_fade, 0.001)
	if _left <= 0.0:
		queue_free()
