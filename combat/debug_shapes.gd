class_name DebugShapes
extends Node2D
## 디버그: 부모 노드 아래의 충돌 모양을 반투명하게 그린다 (F1로 켜고 끔).
## 색: 몸통(벽 충돌) 하늘색 / 피격 영역 초록 / 공격 영역 빨강

const COLOR_BODY := Color(0.3, 0.8, 1.0, 0.45)
const COLOR_HURTBOX := Color(0.2, 1.0, 0.3, 0.45)
const COLOR_HITBOX := Color(1.0, 0.25, 0.2, 0.55)


func _ready() -> void:
	z_index = 100
	z_as_relative = false
	visible = Debug.show_hitboxes
	Events.debug_flags_changed.connect(_on_debug_flags_changed)


func _on_debug_flags_changed() -> void:
	visible = Debug.show_hitboxes
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	_draw_children(get_parent())
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_children(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionShape2D:
			var cs := child as CollisionShape2D
			if cs.shape != null and not cs.disabled:
				draw_set_transform_matrix(global_transform.affine_inverse() * cs.global_transform)
				cs.shape.draw(get_canvas_item(), _color_for(cs.get_parent()))
		_draw_children(child)


func _color_for(owner_node: Node) -> Color:
	if owner_node is Hurtbox:
		return COLOR_HURTBOX
	if owner_node is HitArea:
		return COLOR_HITBOX
	return COLOR_BODY
