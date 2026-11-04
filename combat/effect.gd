class_name Effect
extends AnimatedSprite2D
## 한 번 재생하고 사라지는 이펙트 (화면 표시 전용, 게임 로직에 영향 없음)

const GROUP := &"effects"


static func spawn(anim: StringName, pos: Vector2, rot: float = 0.0, scale_value: float = 1.0) -> Effect:
	var tree := Engine.get_main_loop() as SceneTree
	var container: Node = tree.get_first_node_in_group(GROUP)
	if container == null:
		return null
	var e := Effect.new()
	e.sprite_frames = DB.theme.load_sheet("effects")
	e.position = pos
	e.rotation = rot
	e.scale = Vector2.ONE * scale_value
	e.animation_finished.connect(e.queue_free)
	container.add_child(e)
	e.play(anim)
	return e
