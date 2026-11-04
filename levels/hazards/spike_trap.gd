class_name SpikeTrap
extends Node2D
## 가시 함정. 게임 틱 기준 고정 주기로 오르내린다 (결정론, 경로 연구 가능).
## 올라와 있을 때 플레이어가 닿으면 피해. 회피 무적이면 통과.

const MAX_RESULTS := 4

## 위상 차이 (틱). 맵 글자 'x' 는 SpikeData.alt_phase_ticks
var phase: int = 0
var data: SpikeData

var _sprite: AnimatedSprite2D
var _query := PhysicsShapeQueryParameters2D.new()
var _hitbox: Hitbox


## 맵에서 생성될 때: 'x' 는 'X' 와 엇갈린 위상
func setup_from_map(ch: String, _cell: Vector2i) -> void:
	if ch == "x":
		phase = DB.spike.alt_phase_ticks


func _ready() -> void:
	data = DB.spike
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = DB.theme.load_sheet("props")
	add_child(_sprite)
	var rect := RectangleShape2D.new()
	rect.size = Vector2.ONE * data.hitbox_size
	_query.shape = rect
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	_query.collision_mask = Layers.PLAYER_HURTBOX
	# 디버그 히트박스 표시용 (판정 자체는 쿼리로 한다)
	_hitbox = Hitbox.new()
	_hitbox.collision_layer = 0
	_hitbox.set_rect(rect.size)
	add_child(_hitbox)
	add_child(DebugShapes.new())
	_update()


## 지금 주기 안의 위치 (0 ~ 주기-1). 앞쪽 down_ticks 는 내려감, 뒤쪽 up_ticks 는 올라옴
func cycle_pos() -> int:
	var period := data.up_ticks + data.down_ticks
	return posmod(Game.tick + phase, period)


func is_up() -> bool:
	return cycle_pos() >= data.down_ticks


func _physics_process(_delta: float) -> void:
	_update()
	if not is_up():
		return
	_query.transform = Transform2D(0.0, global_position)
	for r: Dictionary in get_world_2d().direct_space_state.intersect_shape(_query, MAX_RESULTS):
		var hb := r.get("collider") as Hurtbox
		if hb:
			hb.receive_hit(HitInfo.make(data.damage, HitInfo.Kind.MELEE, Team.ENEMY, Vector2.ZERO, self))


func _update() -> void:
	var pos := cycle_pos()
	var anim := &"spike_down"
	if pos >= data.down_ticks:
		anim = &"spike_up"
	elif pos >= data.down_ticks - data.warn_ticks:
		anim = &"spike_warn"
	if _sprite.animation != anim:
		_sprite.play(anim)
	_hitbox.set_active(is_up())
