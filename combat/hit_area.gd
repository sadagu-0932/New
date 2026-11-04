class_name HitArea
extends Area2D
## 판정 영역 베이스 (Hurtbox: 맞는 곳 / Hitbox: 때리는 곳).
## 모양은 코드로 만든다 (에디터 없이 수정 가능하게).

var shape_node: CollisionShape2D


func set_circle(radius: float, offset: Vector2 = Vector2.ZERO) -> void:
	var circle := CircleShape2D.new()
	circle.radius = radius
	_set_shape(circle, offset)


func set_rect(size: Vector2, offset: Vector2 = Vector2.ZERO) -> void:
	var rect := RectangleShape2D.new()
	rect.size = size
	_set_shape(rect, offset)


func set_enabled(value: bool) -> void:
	if shape_node:
		shape_node.set_deferred(&"disabled", not value)


func _set_shape(shape: Shape2D, offset: Vector2) -> void:
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		add_child(shape_node)
	shape_node.shape = shape
	shape_node.position = offset
