class_name CrystalSwitch
extends StaticBody2D
## 수정 스위치 (맵 글자 'W'). 반사탄(패링한 탄)에 맞아야만 켜진다.
## 일반 사격·근접으로는 켜지지 않는다 → 패링을 쓰게 만드는 장치.

var is_on: bool = false
var hurtbox: Hurtbox
var _sprite: AnimatedSprite2D


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	var data := DB.crystal_switch
	circle.radius = data.body_radius
	shape.shape = circle
	shape.position = Vector2(0, data.body_offset_y)
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = DB.theme.load_sheet("props")
	_sprite.play(&"switch_off")
	add_child(_sprite)
	hurtbox = Hurtbox.new()
	hurtbox.collision_layer = Layers.ENEMY_HURTBOX
	hurtbox.set_circle(data.hurtbox_radius)
	hurtbox.handler = _on_hurt
	add_child(hurtbox)
	add_child(DebugShapes.new())


## 꺼져 있으면 은은하게 깜빡여 "이걸 맞히는 것"이 보이게 (화면 표시 전용)
func _physics_process(_delta: float) -> void:
	if is_on:
		_sprite.modulate = Color.WHITE
		return
	var data := DB.crystal_switch
	var t := float(Game.tick % maxi(data.pulse_period_ticks, 1)) / float(maxi(data.pulse_period_ticks, 1))
	var glow := 1.0 + data.pulse_strength * (0.5 - 0.5 * cos(TAU * t))
	_sprite.modulate = Color(glow, glow, glow)


func _on_hurt(hit: HitInfo) -> Hurtbox.Result:
	if hit.kind == HitInfo.Kind.REFLECT and not is_on:
		is_on = true
		_sprite.play(&"switch_on")
		Effect.spawn(&"perfect", global_position, 0.0, 2.0)
		Events.switch_activated.emit(self)
	# 일반 탄도 막는다 (맞고 사라짐)
	return Hurtbox.Result.HIT
