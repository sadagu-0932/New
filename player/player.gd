class_name Player
extends CharacterBody2D
## 플레이어. 자식 노드는 전부 코드로 만든다.
## 상태: 일반 / 회피  (TODO(M2): 사격·근접·패링 추가, TODO(M3): 피격·사망)

enum State { NORMAL, DODGE }

var data: PlayerData
var state: State = State.NORMAL
var dodge: DodgeAbility
## 조준 방향 (길이 1)
var aim_dir: Vector2 = Vector2.RIGHT
var camera: Camera2D

var _sprite: AnimatedSprite2D
var _hurtbox: Hurtbox


func _ready() -> void:
	data = DB.player
	dodge = DB.dodge.create_ability()
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_build_children()


func _build_children() -> void:
	var body_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = data.body_radius
	body_shape.shape = circle
	body_shape.position = Vector2(0, data.body_offset_y)
	add_child(body_shape)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = DB.theme.load_sheet("player")
	_sprite.play(&"idle")
	add_child(_sprite)

	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = Layers.PLAYER_HURTBOX
	_hurtbox.set_circle(data.hurtbox_radius, Vector2(0, data.hurtbox_offset_y))
	add_child(_hurtbox)

	camera = Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)

	add_child(DebugShapes.new())


func _physics_process(_delta: float) -> void:
	var input := PlayerInput.current
	_update_aim(input)
	dodge.tick_cooldown()
	match state:
		State.NORMAL:
			_tick_normal(input)
		State.DODGE:
			_tick_dodge()
	move_and_slide()
	_update_visual(input)


func _tick_normal(input: InputFrame) -> void:
	if input.is_pressed(InputFrame.DODGE) and dodge.can_start():
		# 이동 입력이 없으면 조준 방향으로 회피
		var dir := input.move if input.move != Vector2.ZERO else aim_dir
		dodge.start(dir)
		state = State.DODGE
		Events.player_dodged.emit(self)
		_tick_dodge()
		return
	velocity = input.move * data.move_speed


func _tick_dodge() -> void:
	velocity = dodge.tick()
	if not dodge.is_active():
		state = State.NORMAL


func _update_aim(input: InputFrame) -> void:
	var to_aim := input.aim - global_position
	if to_aim.length_squared() > 1.0:
		aim_dir = to_aim.normalized()


## 지금 무적인지 (회피 무적, 디버그 무적)
func is_invulnerable() -> bool:
	return Debug.god_mode or dodge.is_invulnerable()


## 디버그 이동 등 순간이동 (보간 끊기)
func teleport(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	reset_physics_interpolation()


func _update_visual(input: InputFrame) -> void:
	var anim: StringName = &"idle"
	match state:
		State.DODGE:
			anim = &"dodge"
			_sprite.flip_h = dodge.direction().x < 0.0
		State.NORMAL:
			anim = &"move" if input.move != Vector2.ZERO else &"idle"
			_sprite.flip_h = aim_dir.x < 0.0
	if _sprite.animation != anim:
		_sprite.play(anim)
	# 무적 중엔 살짝 반투명 (디버그 무적은 제외)
	_sprite.modulate.a = 0.6 if dodge.is_invulnerable() else 1.0
