class_name ScreenFx
extends CanvasLayer
## 화면 연출: 흔들림·번쩍임 (부스 관객이 완벽 판정·처형을 알아보기 쉽게).
## 화면 표시 전용 — 게임 로직·RNG·기록에 영향 없음 (연출용 랜덤은 따로 씀).

var _flash: ColorRect
var _flash_alpha: float = 0.0
var _flash_time: float = 0.0
var _flash_left: float = 0.0
var _shake_px: float = 0.0
var _shake_time: float = 0.0
var _shake_left: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 88
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)
	var f := DB.feel
	Events.player_hit.connect(func(_h: HitInfo) -> void:
		shake(f.shake_hit)
		flash(Color(0.9, 0.2, 0.25), f.flash_hit))
	Events.parried.connect(func(perfect: bool) -> void:
		if perfect:
			shake(f.shake_perfect)
			flash(Color.WHITE, f.flash_perfect))
	Events.perfect_dodge.connect(func() -> void:
		shake(f.shake_perfect)
		flash(Color(0.6, 0.9, 1.0), f.flash_perfect))
	Events.executed.connect(func() -> void:
		shake(f.shake_execute)
		flash(Color.WHITE, f.flash_perfect))
	Events.boss_groggy.connect(func() -> void: shake(f.shake_groggy))
	Events.enemy_died.connect(func(_e: Node2D) -> void: shake(f.shake_enemy_death))


## 세기(px)·시간(초)
func shake(strength_time: Vector2) -> void:
	if strength_time.x >= _shake_px * (_shake_left / maxf(_shake_time, 0.001)):
		_shake_px = strength_time.x
		_shake_time = strength_time.y
		_shake_left = strength_time.y


## 색·(불투명도, 시간)
func flash(color: Color, alpha_time: Vector2) -> void:
	_flash.color = Color(color.r, color.g, color.b, 0)
	_flash_alpha = alpha_time.x
	_flash_time = alpha_time.y
	_flash_left = alpha_time.y


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		_flash.color.a = _flash_alpha * maxf(_flash_left, 0.0) / maxf(_flash_time, 0.001)
	var cam := get_viewport().get_camera_2d()
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if cam == null or (player and player.cutscene_lock):
		return  # 컷씬은 자체 흔들림을 쓴다
	if _shake_left > 0.0:
		_shake_left -= delta
		var px := _shake_px * maxf(_shake_left, 0.0) / maxf(_shake_time, 0.001)
		cam.offset = Vector2(_rng.randf_range(-px, px), _rng.randf_range(-px, px)).round()
	elif cam.offset != Vector2.ZERO:
		cam.offset = Vector2.ZERO
