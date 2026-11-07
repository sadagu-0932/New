class_name TestTurret
extends StaticBody2D
## 탄 발사대 (맵 글자 'T'). 부술 수 없고 일정 간격으로 플레이어에게 느린 탄을 쏜다.
## 튜토리얼 4구간: 원거리형을 다 잡아도 튕길 탄이 끊기지 않게 (수정 스위치를 켤 수 있게).
## 플레이어가 투명이면 마지막으로 본 위치에 쏜다 (적 공통 로직의 맛보기, M3에서 적 베이스로 옮김).

var data: TestTurretData
var _timer: int = 0
var _last_seen: Vector2 = Vector2.ZERO
var _has_seen: bool = false


func _ready() -> void:
	data = DB.test_turret
	collision_layer = Layers.WORLD
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2.ONE * data.body_size
	shape.shape = rect
	add_child(shape)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = DB.theme.load_sheet("props")
	sprite.play(&"turret_idle")
	add_child(sprite)
	_timer = data.fire_interval_ticks


func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null:
		return
	if not player.is_stealthed():
		_last_seen = player.global_position
		_has_seen = true
	if not _has_seen or global_position.distance_to(_last_seen) > data.fire_range:
		return
	_timer -= 1
	if _timer > 0:
		return
	_timer = data.fire_interval_ticks
	var container := get_tree().get_first_node_in_group(Level.GROUP_PROJECTILES)
	var dir := (_last_seen - global_position).normalized()
	# 포탑 몸통(벽 레이어) 밖에서 탄 생성
	Projectile.spawn(container, Team.ENEMY, global_position + dir * data.muzzle_offset, dir, data.projectile)
