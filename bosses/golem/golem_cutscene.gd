class_name GolemCutscene
extends Node
## 2페이즈 시작 컷씬 (대사 없음). 골렘 1페이즈 격파 직후 (타이머는 이미 멈춤 → 기록에 영향 없음).
## 1. 골렘 각성  2. 필살기 1회  3. 주인공 쓰러짐  4. 암전  5. TO BE CONTINUED → Events.demo_finished (기록 화면, M7)
## 첫 회는 끝까지 재생, 두 번째부터 E·Enter 로 건너뛰기 가능 (SaveData "golem_cutscene_seen").
## 데모 모드가 아니면(본편) 3~5 대신 2페이즈 전투로 이어진다.

enum Step { AWAKEN, SPECIAL, COLLAPSE, FADE, TEXT, DONE }

const SAVE_KEY := "golem_cutscene_seen"
## 화면 흔들림 세기 (px, 화면 표시 전용)
const SHAKE_PX := 3.0

var golem: Golem
var step: Step = Step.AWAKEN
var skippable: bool = false

var _timer: int = 0
var _player: Player
var _layer: CanvasLayer
var _black: ColorRect
var _text: Label
var _skip_label: Label
## 화면 연출용 랜덤 (게임 로직 RNG 와 분리)
var _fx_rng := RandomNumberGenerator.new()
var _fake_bullets: Array[Node2D] = []


func _init(owner_golem: Golem) -> void:
	golem = owner_golem


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if _player:
		_player.set_cutscene_lock(true)
	# 남은 적 탄 정리
	for node in get_tree().get_nodes_in_group(Projectile.GROUP_ENEMY):
		(node as Projectile).destroy(false)
	skippable = bool(SaveData.get_value(SAVE_KEY, false))
	_build_overlay()
	_enter(Step.AWAKEN)


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_black)
	_text = UiText.make_label("TO BE CONTINUED", UiText.SIZE_LARGE)
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.visible = false
	_layer.add_child(_text)
	_skip_label = UiText.make_label("E 건너뛰기")
	_skip_label.position = Vector2(320 - 60, 180 - 16)
	_skip_label.modulate.a = 0.7
	_skip_label.visible = skippable
	_layer.add_child(_skip_label)


func _enter(s: Step) -> void:
	step = s
	var d := golem.gd()
	match s:
		Step.AWAKEN:
			_timer = d.cut_awaken_ticks
			golem.sprite.play(&"awaken")
		Step.SPECIAL:
			_timer = d.cut_special_ticks
			golem.sprite.play(&"special")
			_spawn_special()
		Step.COLLAPSE:
			_timer = d.cut_collapse_ticks
			if _player:
				_player.cutscene_collapse()
		Step.FADE:
			_timer = d.cut_fade_ticks
		Step.TEXT:
			_timer = d.cut_text_ticks
			_black.color.a = 1.0
			_text.visible = true
		Step.DONE:
			_finish()


func _physics_process(_delta: float) -> void:
	if step == Step.DONE:
		return
	if skippable and (Input.is_action_just_pressed(&"interact") or Input.is_action_just_pressed(&"menu_confirm")):
		skip()
		return
	_timer -= 1
	match step:
		Step.AWAKEN:
			_shake(SHAKE_PX)
		Step.SPECIAL:
			_shake(SHAKE_PX * 2.0)
			_move_fake_bullets()
		Step.COLLAPSE:
			_shake(0.0)
			_move_fake_bullets()
		Step.FADE:
			_black.color.a = 1.0 - float(_timer) / float(maxi(golem.gd().cut_fade_ticks, 1))
	if _timer > 0:
		return
	match step:
		Step.AWAKEN:
			_enter(Step.SPECIAL)
		Step.SPECIAL:
			if Game.is_demo_mode():
				_enter(Step.COLLAPSE)
			else:
				_finish_into_phase2()
		Step.COLLAPSE:
			_enter(Step.FADE)
		Step.FADE:
			_enter(Step.TEXT)
		Step.TEXT:
			_enter(Step.DONE)


## 건너뛰기 (두 번째 시청부터)
func skip() -> void:
	if not skippable or step == Step.DONE:
		return
	if not Game.is_demo_mode():
		_finish_into_phase2()
		return
	_enter(Step.DONE)


func _finish() -> void:
	step = Step.DONE
	_shake(0.0)
	SaveData.set_value(SAVE_KEY, true)
	Events.demo_finished.emit()


## 본편: 쓰러지지 않고 2페이즈 전투로
func _finish_into_phase2() -> void:
	step = Step.DONE
	_shake(0.0)
	SaveData.set_value(SAVE_KEY, true)
	_clear_fake_bullets()
	if _player:
		_player.set_cutscene_lock(false)
	golem.start_phase2()
	queue_free()


## 필살기 연출: 사방으로 큰 탄막 (판정 없는 그림)
func _spawn_special() -> void:
	var d := golem.gd()
	var frames := DB.theme.load_sheet("bullets")
	for i in d.cut_special_bullets:
		var b := AnimatedSprite2D.new()
		b.sprite_frames = frames
		b.play(&"enemy")
		b.scale = Vector2.ONE * 2.0
		b.position = golem.global_position
		b.set_meta(&"dir", Vector2.RIGHT.rotated(TAU * i / d.cut_special_bullets))
		golem.get_parent().add_child(b)
		_fake_bullets.append(b)
	Effect.spawn(&"shockwave", golem.global_position, 0.0, 8.0, "skill_fx")


func _move_fake_bullets() -> void:
	for b in _fake_bullets:
		if is_instance_valid(b):
			b.position += (b.get_meta(&"dir") as Vector2) * 3.0


func _clear_fake_bullets() -> void:
	for b in _fake_bullets:
		if is_instance_valid(b):
			b.queue_free()
	_fake_bullets.clear()


func _shake(px: float) -> void:
	if _player and _player.camera:
		_player.camera.offset = Vector2(_fx_rng.randf_range(-px, px), _fx_rng.randf_range(-px, px)) if px > 0.0 else Vector2.ZERO


func _exit_tree() -> void:
	_clear_fake_bullets()
