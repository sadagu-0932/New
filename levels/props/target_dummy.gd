class_name TargetDummy
extends StaticBody2D
## 연습용 허수아비. 맞으면 반짝이고 받은 데미지를 센다 (죽지 않음).

var damage_taken: int = 0
var hit_count: int = 0
var hurtbox: Hurtbox

var _sprite: AnimatedSprite2D


func _ready() -> void:
	var data := DB.target_dummy
	collision_layer = Layers.ENEMY
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = data.body_radius
	shape.shape = circle
	add_child(shape)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = DB.theme.load_sheet("props")
	_sprite.play(&"dummy_idle")
	_sprite.animation_finished.connect(func() -> void: _sprite.play(&"dummy_idle"))
	add_child(_sprite)

	hurtbox = Hurtbox.new()
	hurtbox.collision_layer = Layers.ENEMY_HURTBOX
	hurtbox.set_circle(data.hurtbox_radius)
	hurtbox.handler = _on_hurt
	add_child(hurtbox)
	add_child(DebugShapes.new())


func _on_hurt(hit: HitInfo) -> Hurtbox.Result:
	damage_taken += hit.damage
	hit_count += 1
	_sprite.play(&"dummy_hit")
	return Hurtbox.Result.HIT
