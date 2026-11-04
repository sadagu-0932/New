class_name Enemy
extends CharacterBody2D
## 적 베이스. 종류별 행동은 하위 클래스의 _tick_ai() 에서 정한다.
## 공통 기능:
##  - 인식: 시야 거리 안 + 벽에 가리지 않으면 플레이어를 봄
##  - 투명한 플레이어는 보지 못하고, 마지막으로 본 위치(target_pos)로 간다
##  - 체력·피격 넉백·접촉 데미지·사망

const GROUP := &"enemies"
const MAX_RESULTS := 8
## 맞았을 때 반짝이는 틱 (화면 표시 전용)
const HURT_FLASH_TICKS := 8

var data: EnemyData
var hp: int = 0
var hurtbox: Hurtbox
var sprite: AnimatedSprite2D
var dead: bool = false
## 한 번이라도 플레이어를 봤는지 (안 봤으면 가만히 있음)
var has_target: bool = false
## 이번 틱에 플레이어가 보이는지
var sees_player: bool = false
## 마지막으로 본 플레이어 위치
var target_pos: Vector2 = Vector2.ZERO

var _knock: Vector2 = Vector2.ZERO
var _knock_ticks: int = 0
var _hurt_flash: int = 0
var _contact_query := PhysicsShapeQueryParameters2D.new()


func _ready() -> void:
	add_to_group(GROUP)
	hp = data.max_hp
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD | Layers.ENEMY | Layers.PLAYER | Layers.PIT
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	var body_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = data.body_radius
	body_shape.shape = circle
	add_child(body_shape)

	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = DB.theme.load_sheet(data.sheet)
	sprite.play(&"idle")
	add_child(sprite)

	hurtbox = Hurtbox.new()
	hurtbox.collision_layer = Layers.ENEMY_HURTBOX
	hurtbox.set_circle(data.hurtbox_radius)
	hurtbox.handler = _on_hurt
	add_child(hurtbox)

	var contact := CircleShape2D.new()
	contact.radius = data.body_radius + 1.0
	_contact_query.shape = contact
	_contact_query.collide_with_areas = true
	_contact_query.collide_with_bodies = false
	_contact_query.collision_mask = Layers.PLAYER_HURTBOX

	add_child(DebugShapes.new())
	_on_ready()


## 하위 클래스 초기화용
func _on_ready() -> void:
	pass


func _physics_process(_delta: float) -> void:
	if dead:
		return
	_update_perception()
	if _knock_ticks > 0:
		_knock_ticks -= 1
		velocity = _knock
	else:
		_tick_ai()
	move_and_slide()
	_contact_damage()
	_update_visual()


## 하위 클래스가 velocity 를 정한다
func _tick_ai() -> void:
	velocity = Vector2.ZERO


## 지금 보여줄 애니메이션 (하위 클래스가 덮어씀)
func _anim() -> StringName:
	return &"move" if velocity != Vector2.ZERO else &"idle"


func get_player() -> Player:
	return get_tree().get_first_node_in_group(Player.GROUP) as Player


func _update_perception() -> void:
	sees_player = false
	var player := get_player()
	if player == null or player.is_dead() or player.is_stealthed():
		return  # 투명이면 놓친다: target_pos 는 마지막으로 본 위치 그대로
	var to_player := player.global_position - global_position
	if to_player.length() > data.sight_range:
		return
	if not _line_of_sight(player.global_position):
		return
	sees_player = true
	has_target = true
	target_pos = player.global_position


func _line_of_sight(to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, to, Layers.WORLD, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## pos 쪽으로 speed 로 이동. 도착했으면 멈추고 true
func move_to(pos: Vector2, speed: float) -> bool:
	var to := pos - global_position
	if to.length() <= data.arrive_distance:
		velocity = Vector2.ZERO
		return true
	velocity = to.normalized() * speed
	return false


func dir_to_target() -> Vector2:
	var to := target_pos - global_position
	return to.normalized() if to != Vector2.ZERO else Vector2.RIGHT


func _contact_damage() -> void:
	if data.contact_damage <= 0:
		return
	_contact_query.transform = Transform2D(0.0, global_position)
	for r: Dictionary in get_world_2d().direct_space_state.intersect_shape(_contact_query, MAX_RESULTS):
		var hb := r.get("collider") as Hurtbox
		if hb:
			var dir := (hb.global_position - global_position).normalized()
			hb.receive_hit(HitInfo.make(data.contact_damage, HitInfo.Kind.MELEE, Team.ENEMY, dir, self))


func _on_hurt(hit: HitInfo) -> Hurtbox.Result:
	if dead:
		return Hurtbox.Result.IGNORED
	hp -= hit.damage
	_hurt_flash = HURT_FLASH_TICKS
	Events.enemy_damaged.emit(self, hit)
	# 맞으면 플레이어를 알아챈다 (투명이면 위치는 모름)
	var player := get_player()
	if player and not player.is_stealthed():
		has_target = true
		target_pos = player.global_position
	if hp <= 0:
		_die()
	elif data.knockback_ticks > 0 and hit.direction != Vector2.ZERO:
		_knock = hit.direction.normalized() * data.knockback_speed
		_knock_ticks = data.knockback_ticks
	return Hurtbox.Result.HIT


func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	hurtbox.shape_node.disabled = true
	Effect.spawn(&"enemy_death", global_position)
	Events.enemy_died.emit(self)
	queue_free()


func _update_visual() -> void:
	var anim := _anim()
	if _hurt_flash > 0:
		_hurt_flash -= 1
		anim = &"hurt"
	if sprite.animation != anim:
		sprite.play(anim)
	var face_x := velocity.x
	if absf(face_x) < 0.01:
		face_x = target_pos.x - global_position.x if has_target else 1.0
	sprite.flip_h = face_x < 0.0
