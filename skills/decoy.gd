class_name Decoy
extends Node2D
## 미끼 분신. 적은 분신이 보이면 플레이어 대신 분신을 노린다 (Enemy._update_perception).
## 시간이 지나거나 여러 번 맞으면 사라진다.

const GROUP := &"decoys"

var data: DecoyData
var hp: int = 0
var hurtbox: Hurtbox
var _left: int = 0
var _sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group(GROUP)
	hp = data.hp
	_left = data.duration_ticks
	var cloak := AnimatedSprite2D.new()
	cloak.sprite_frames = DB.theme.load_sheet("player_cloak")
	cloak.play(&"cloak_hang")
	cloak.offset = Vector2(-4, SpriteSheet.foot_offset(DB.theme.load_sheet("player")).y)
	cloak.modulate = Color(0.7, 0.8, 1.0, 0.75)
	add_child(cloak)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = DB.theme.load_sheet("player")
	_sprite.offset = SpriteSheet.foot_offset(_sprite.sprite_frames)
	_sprite.play(&"idle")
	_sprite.modulate = Color(0.7, 0.8, 1.0, 0.75)
	add_child(_sprite)
	hurtbox = Hurtbox.new()
	hurtbox.collision_layer = Layers.PLAYER_HURTBOX
	hurtbox.set_circle(DB.player.hurtbox_radius, Vector2(0, DB.player.hurtbox_offset_y))
	hurtbox.handler = _on_hurt
	add_child(hurtbox)
	add_child(DebugShapes.new())


func is_alive() -> bool:
	return _left > 0 and hp > 0


func _physics_process(_delta: float) -> void:
	_left -= 1
	if _left <= 0:
		vanish()


func _on_hurt(hit: HitInfo) -> Hurtbox.Result:
	if not is_alive():
		return Hurtbox.Result.IGNORED
	hp -= maxi(hit.damage, 1)
	_sprite.modulate = Color(1, 1, 1, 0.9)
	if hp <= 0:
		vanish()
	return Hurtbox.Result.HIT


func vanish() -> void:
	if is_queued_for_deletion():
		return
	_left = 0
	remove_from_group(GROUP)
	hurtbox.shape_node.disabled = true
	Effect.spawn(&"stealth_puff", global_position)
	queue_free()
