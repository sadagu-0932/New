class_name Decoy
extends Node2D
## 미끼 분신. 적은 분신이 보이면 플레이어 대신 분신을 노린다 (Enemy._update_perception).
## 시간이 지나거나 여러 번 맞으면 사라진다.

const GROUP := &"decoys"

var data: DecoyData
## 분신 그림 방향 (만들 때 플레이어가 보던 방향을 받는다)
var view: Player.View = Player.View.SIDE
var flip: bool = false
var hp: int = 0
var hurtbox: Hurtbox
var _left: int = 0
var _sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group(GROUP)
	hp = data.hp
	_left = data.duration_ticks
	var names: Array = Player.VIEW_SHEETS[view]
	var cloak := AnimatedSprite2D.new()
	cloak.sprite_frames = DB.theme.load_sheet(names[1])
	cloak.play(&"cloak_hang")
	cloak.modulate = Color(0.7, 0.8, 1.0, 0.75)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = DB.theme.load_sheet(names[0])
	_sprite.offset = SpriteSheet.foot_offset(_sprite.sprite_frames)
	_sprite.flip_h = flip
	_sprite.play(&"idle")
	_sprite.modulate = Color(0.7, 0.8, 1.0, 0.75)
	# 망토는 몸 기준 위치에 (옆모습은 뒤쪽으로 4px, 정면·뒷모습은 가운데)
	var side_x := 0.0
	if view == Player.View.SIDE:
		side_x = 4.0 if flip else -4.0
	cloak.flip_h = flip
	cloak.offset = Vector2(side_x, _sprite.offset.y)
	# 총: 보던 방향을 겨눈 채로 어깨에 (화면 표시 전용)
	var gun := AnimatedSprite2D.new()
	gun.sprite_frames = DB.theme.load_sheet("gun")
	gun.play(&"idle")
	gun.centered = false
	var pivot: Array = DB.theme.load_json("gun").get("pivot", [0.0, 0.0])
	gun.offset = -Vector2(float(pivot[0]), float(pivot[1]))
	var sh: Array = DB.theme.load_json(names[0]).get("shoulder", [8.0, 12.0])
	var facing := -1.0 if flip else 1.0
	gun.position = Vector2((float(sh[0]) - 8.0) * facing, float(sh[1]) - 12.0 + _sprite.offset.y)
	var dir := {Player.View.SIDE: Vector2(facing, 0), Player.View.FRONT: Vector2.DOWN, Player.View.BACK: Vector2.UP}[view] as Vector2
	gun.rotation = dir.angle()
	gun.flip_v = dir.x < 0.0
	gun.modulate = _sprite.modulate
	# 뒷모습이면 총 → 몸 → 목도리 꼬리, 아니면 꼬리 → 몸 → 총
	var order: Array = [gun, _sprite, cloak] if view == Player.View.BACK else [cloak, _sprite, gun]
	for n: Node in order:
		add_child(n)
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
