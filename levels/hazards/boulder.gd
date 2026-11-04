class_name Boulder
extends Node2D
## 굴러가는 바위. 플레이어에게 닿으면 피해, 벽에 닿으면 부서진다.
## 패링되지 않는다 (탄이 아님). 회피 무적으로 통과 가능.

const MAX_RESULTS := 4

var velocity: Vector2 = Vector2.ZERO
var data: BoulderData
var alive: bool = true

var _lifetime: int = 0
var _query := PhysicsShapeQueryParameters2D.new()
var _sprite: AnimatedSprite2D


func _ready() -> void:
	var circle := CircleShape2D.new()
	circle.radius = data.radius
	_query.shape = circle
	_query.collide_with_areas = true
	_query.collide_with_bodies = true
	_lifetime = data.lifetime_ticks
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = DB.theme.load_sheet("props")
	_sprite.play(&"boulder")
	add_child(_sprite)


func _physics_process(_delta: float) -> void:
	if not alive:
		return
	position += velocity / float(Game.config.tick_rate)
	_lifetime -= 1
	_query.transform = Transform2D(0.0, global_position)
	var space := get_world_2d().direct_space_state
	_query.collision_mask = Layers.PLAYER_HURTBOX
	for r: Dictionary in space.intersect_shape(_query, MAX_RESULTS):
		var hb := r.get("collider") as Hurtbox
		if hb:
			hb.receive_hit(HitInfo.make(data.damage, HitInfo.Kind.MELEE, Team.ENEMY, velocity.normalized(), self))
	_query.collision_mask = Layers.WORLD
	if _lifetime <= 0 or not space.intersect_shape(_query, 1).is_empty():
		alive = false
		Effect.spawn(&"enemy_death", global_position)
		queue_free()
	if Debug.show_hitboxes:
		queue_redraw()


func _draw() -> void:
	if Debug.show_hitboxes:
		draw_circle(Vector2.ZERO, data.radius, DebugShapes.COLOR_HITBOX)
