class_name AbsorbSkill
extends Skill
## 흡수 장막: 일정 시간 조준 방향 앞에 장막을 펼쳐, 닿는 적 탄을 없애고 탄약으로 바꾼다.

var _left: int = 0
var _hitbox: Hitbox
var _sprite: AnimatedSprite2D


func _ad() -> AbsorbData:
	return data as AbsorbData


func _ready() -> void:
	_hitbox = Hitbox.new()
	_hitbox.collision_layer = Layers.PLAYER_ATTACK
	_hitbox.set_circle(_ad().radius)
	_hitbox.parry_handler = _absorb
	add_child(_hitbox)
	_hitbox.set_active(false)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = DB.theme.load_sheet("skill_fx")
	_sprite.play(&"barrier")
	_sprite.scale = Vector2.ONE * _ad().sprite_scale
	_sprite.visible = false
	add_child(_sprite)


func is_active() -> bool:
	return _left > 0


func _activate() -> bool:
	_left = _ad().duration_ticks
	_follow_aim()
	_hitbox.set_active(true)
	_sprite.visible = true
	return true


func _tick_effect() -> void:
	if _left <= 0:
		return
	_left -= 1
	_follow_aim()
	if _left == 0:
		_hitbox.set_active(false)
		_sprite.visible = false


func _follow_aim() -> void:
	var dir := player.aim_dir
	_hitbox.position = dir * _ad().offset
	_sprite.position = _hitbox.position
	_sprite.rotation = dir.angle()


func _absorb(projectile: Projectile) -> bool:
	if not is_active() or projectile.team != Team.ENEMY:
		return false
	projectile.destroy(false)
	player.ammo.add(_ad().ammo_per_bullet)
	Effect.spawn(&"parry", projectile.global_position)
	return true


func cleanup() -> void:
	_left = 0
	if _hitbox:
		_hitbox.set_active(false)
