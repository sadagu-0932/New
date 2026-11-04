class_name Player
extends CharacterBody2D
## 플레이어. 자식 노드는 전부 코드로 만든다.
## 상태: 일반 / 회피 / 돌진 베기 / 쓰러짐. 사격·근접은 일반 상태 위에서 겹쳐 동작한다.
## 전투 루프: 사격 → 탄약 소진 → 근접·패링 → 탄약 회복 (자동 재장전 없음)
## ※ 숨은 테크(은신 처형·돌진 베기·연속 퍼펙트 콤보, 재패링은 MeleeAttack)는 게임 안 어디에도 안내하지 않는다.

enum State { NORMAL, DODGE, DASH_SLASH, DEAD }

const GROUP := &"player"
## 피격 모션 표시 틱 (화면 표시 전용)
const HURT_ANIM_TICKS := 8

var data: PlayerData
var state: State = State.NORMAL
var dodge: DodgeAbility
var gun: Gun
var ammo: Ammo
var health: Health
var melee: MeleeAttack
## 장착 스킬 (없을 수 있음)
var skill: Skill
## 조준 방향 (길이 1)
var aim_dir: Vector2 = Vector2.RIGHT
var camera: Camera2D
## 투명 남은 틱 (0 = 보임)
var stealth_ticks_left: int = 0
## 피격 후 무적 남은 틱
var hurt_invuln_left: int = 0
## 컷씬 중: 조작 불가·무적
var cutscene_lock: bool = false
## (숨은 테크 4) 연속 퍼펙트 콤보
var combo: Combo

var _sprite: AnimatedSprite2D
var _hurtbox: Hurtbox
## 이번 회피에서 이미 완벽 회피가 났는지 (한 번의 회피에 한 번만)
var _perfect_dodge_this_dodge: bool = false
## 사격 모션 표시용 남은 틱 (화면 표시 전용)
var _shoot_anim_ticks: int = 0
## 돌진 베기 남은 틱·방향·속도
var _dash_left: int = 0
var _dash_dir: Vector2 = Vector2.RIGHT
var _dash_speed: float = 0.0
## 콤보 단계 표시 (캐릭터 주변 이펙트, 숫자 없음)
var _aura: AnimatedSprite2D


func _ready() -> void:
	add_to_group(GROUP)
	data = DB.player
	dodge = DB.dodge.create_ability()
	gun = Gun.new(DB.gun)
	ammo = Ammo.new(DB.gun.magazine_size, DB.gun.start_ammo)
	health = Health.new(data.max_hp)
	combo = Combo.new(DB.advanced)
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.ENEMY | Layers.PIT
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_build_children()
	Events.player_spawned.emit(self)


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
	_hurtbox.handler = _on_hurt
	add_child(_hurtbox)

	melee = MeleeAttack.new(DB.melee, DB.parry)
	melee.parried.connect(_on_parried)
	melee.reparried.connect(_on_reparried)
	add_child(melee)

	_aura = AnimatedSprite2D.new()
	_aura.sprite_frames = DB.theme.load_sheet("effects")
	_aura.play(&"combo_aura")
	_aura.show_behind_parent = true
	_aura.visible = false
	add_child(_aura)

	camera = Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)

	add_child(DebugShapes.new())


func _physics_process(_delta: float) -> void:
	var input := PlayerInput.current
	if state == State.DEAD:
		velocity = Vector2.ZERO
		return
	if cutscene_lock:
		velocity = Vector2.ZERO
		if _sprite.animation != &"idle":
			_sprite.play(&"idle")
		_sprite.modulate = Color.WHITE
		return
	_update_aim(input)
	melee.aim_dir = aim_dir
	combo.tick()
	melee.damage_mult = combo.damage_mult()
	dodge.tick_cooldown()
	gun.tick_cooldown()
	_tick_stealth()
	if hurt_invuln_left > 0:
		hurt_invuln_left -= 1
	match state:
		State.NORMAL:
			_tick_normal(input)
		State.DODGE:
			_tick_dodge(input)
		State.DASH_SLASH:
			_tick_dash_slash()
	if skill:
		skill.tick()
	var hits := melee.tick()
	if hits > 0:
		ammo.add(hits * DB.melee.ammo_on_hit)
		Events.melee_hit.emit(hits)
	move_and_slide()
	_update_visual(input)


func _tick_normal(input: InputFrame) -> void:
	if input.is_pressed(InputFrame.DODGE) and dodge.can_start():
		# 이동 입력이 없으면 조준 방향으로 회피
		var dir := input.move if input.move != Vector2.ZERO else aim_dir
		melee.cancel()
		dodge.start(dir)
		_perfect_dodge_this_dodge = false
		state = State.DODGE
		Events.player_dodged.emit(self)
		_tick_dodge(input)
		return
	if input.is_pressed(InputFrame.INTERACT) and is_stealthed() and _try_execute():
		return
	if input.is_pressed(InputFrame.SKILL) and skill:
		skill.try_use()
	if input.is_pressed(InputFrame.MELEE) and melee.can_start():
		melee.start(aim_dir)
		Events.melee_started.emit()
	elif input.is_held(InputFrame.SHOOT) and not melee.is_active():
		_try_shoot(input)
	var speed := data.move_speed * combo.speed_mult()
	if melee.is_active():
		speed *= DB.melee.move_speed_mult
	velocity = input.move * speed


func _try_shoot(input: InputFrame) -> void:
	if ammo.current <= 0:
		if input.is_pressed(InputFrame.SHOOT):
			Events.ammo_empty.emit()
		return
	var container := get_tree().get_first_node_in_group(Level.GROUP_PROJECTILES)
	if gun.try_fire(ammo, container, global_position, aim_dir, combo.damage_mult()):
		_shoot_anim_ticks = DB.gun.fire_interval_ticks
		Events.player_shot.emit()


func _tick_dodge(input: InputFrame = null) -> void:
	# (숨은 테크 3) 돌진 베기: 회피 중 근접 → 회피 이동 거리만큼 돌진하며 베기
	if input and input.is_pressed(InputFrame.MELEE) and dodge.is_active() and melee.can_start():
		_start_dash_slash()
		return
	velocity = dodge.tick()
	_check_perfect_dodge_graze()
	if not dodge.is_active():
		state = State.NORMAL


func _start_dash_slash() -> void:
	var tech := DB.advanced
	_dash_dir = dodge.direction()
	dodge.cancel()
	_dash_left = tech.dash_slash_ticks
	_dash_speed = dodge.total_distance() / float(maxi(tech.dash_slash_ticks, 1)) * float(Game.config.tick_rate)
	state = State.DASH_SLASH
	melee.start(_dash_dir)
	Events.dash_slashed.emit()
	Effect.spawn(&"stealth_puff", global_position)
	_tick_dash_slash()


func _tick_dash_slash() -> void:
	velocity = _dash_dir * _dash_speed
	melee.position = _dash_dir * DB.melee.offset
	_dash_left -= 1
	if _dash_left <= 0:
		state = State.NORMAL


## (숨은 테크 1) 은신 처형: 투명 상태에서 붙어 있는 적에게 큰 데미지 + 탄약 대량 흡수. 투명은 풀린다
func _try_execute() -> bool:
	var tech := DB.advanced
	var target: Enemy = null
	var best := INF
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e == null or e.dead:
			continue
		# 몸 크기를 빼고 잰 거리 (골렘처럼 큰 적도 붙으면 됨)
		var d := global_position.distance_to(e.global_position) - e.data.body_radius
		if d <= tech.execute_range and (d < best or (d == best and target and e.global_position.x < target.global_position.x)):
			target = e
			best = d
	if target == null:
		return false
	var dir := (target.global_position - global_position).normalized()
	var hit := HitInfo.make(ceili(tech.execute_damage * combo.damage_mult()), HitInfo.Kind.EXECUTE, Team.PLAYER, dir, self)
	target.hurtbox.receive_hit(hit)
	ammo.add(tech.execute_ammo)
	stealth_ticks_left = 0
	Events.stealth_changed.emit(false)
	Events.executed.emit()
	Effect.spawn(&"perfect", target.global_position, 0.0, 3.0)
	Effect.spawn(&"enemy_death", target.global_position)
	return true


## 완벽 회피(스침) 판정: 판정창 안에서 적 탄이 몸 가까이 있으면 성공
func _check_perfect_dodge_graze() -> void:
	if _perfect_dodge_this_dodge or dodge.elapsed_ticks() > DB.stealth.perfect_dodge_window_ticks:
		return
	var center := _hurtbox.global_position + _hurtbox.shape_node.position
	for node in get_tree().get_nodes_in_group(Projectile.GROUP_ENEMY):
		var p := node as Projectile
		if p == null or not p.alive:
			continue
		var reach := data.hurtbox_radius + p.radius + DB.stealth.perfect_dodge_margin
		if p.global_position.distance_squared_to(center) <= reach * reach:
			_perfect_dodge_this_dodge = true
			_start_stealth()
			return


func _tick_stealth() -> void:
	if stealth_ticks_left > 0:
		stealth_ticks_left -= 1
		if stealth_ticks_left == 0:
			Events.stealth_changed.emit(false)


func _update_aim(input: InputFrame) -> void:
	var to_aim := input.aim - global_position
	if to_aim.length_squared() > 1.0:
		aim_dir = to_aim.normalized()


## 지금 무적인지 (회피 무적, 피격 후 무적, 디버그 무적)
func is_invulnerable() -> bool:
	return Debug.god_mode or cutscene_lock or dodge.is_invulnerable() or hurt_invuln_left > 0 \
		or (state == State.DASH_SLASH and DB.advanced.dash_slash_invuln) \
		or (skill != null and skill.grants_invulnerability())


func is_dead() -> bool:
	return state == State.DEAD


## 투명 상태인지 (적이 플레이어를 놓친다)
func is_stealthed() -> bool:
	return stealth_ticks_left > 0


## 피격 처리. 회피 시작 직후(판정창 안)에 맞을 뻔하면 완벽 회피 → 투명
func _on_hurt(hit: HitInfo) -> Hurtbox.Result:
	if state == State.DEAD:
		return Hurtbox.Result.IGNORED
	if state == State.DODGE and dodge.is_active() \
			and dodge.elapsed_ticks() <= DB.stealth.perfect_dodge_window_ticks:
		if not _perfect_dodge_this_dodge:
			_perfect_dodge_this_dodge = true
			_start_stealth()
		return Hurtbox.Result.IGNORED
	if is_invulnerable():
		return Hurtbox.Result.IGNORED
	health.damage(hit.damage)
	Events.player_hit.emit(hit)
	Events.player_hp_changed.emit(health.current, health.maximum)
	if health.is_dead():
		_die()
	else:
		hurt_invuln_left = data.hurt_invuln_ticks
	return Hurtbox.Result.HIT


## 컷씬 동안 조작을 막는다
func set_cutscene_lock(value: bool) -> void:
	cutscene_lock = value
	velocity = Vector2.ZERO
	melee.cancel()
	stealth_ticks_left = 0


## 컷씬: 쓰러짐 (사망 처리·재시작은 하지 않음)
func cutscene_collapse() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	_sprite.modulate = Color.WHITE
	_sprite.play(&"death")


## 스킬 장착 (출발 전 Tab 설정, 런 시작 시)
func set_skill(data: SkillData) -> void:
	if skill:
		skill.cleanup()
		skill.queue_free()
		skill = null
	if data == null:
		return
	skill = data.create_skill()
	skill.player = self
	add_child(skill)


func _exit_tree() -> void:
	if skill:
		skill.cleanup()


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	melee.cancel()
	stealth_ticks_left = 0
	_sprite.modulate = Color.WHITE
	_sprite.play(&"death")
	Events.player_died.emit()


func _start_stealth() -> void:
	var was_stealthed := is_stealthed()
	stealth_ticks_left = DB.stealth.stealth_ticks
	combo.add()
	Events.perfect_dodge.emit()
	if not was_stealthed:
		Events.stealth_changed.emit(true)
	Effect.spawn(&"perfect", global_position, 0.0, 2.0)
	Effect.spawn(&"stealth_puff", global_position)


func _on_parried(projectile: Projectile, perfect: bool) -> void:
	ammo.add(DB.parry.ammo_on_parry)
	Events.parried.emit(perfect)
	Effect.spawn(&"parry", projectile.global_position)
	if perfect:
		combo.add()
		Effect.spawn(&"perfect", projectile.global_position, 0.0, 2.0)


func _on_reparried(projectile: Projectile) -> void:
	ammo.add(DB.parry.ammo_on_parry)
	Events.reparried.emit(projectile.reflect_count - 1)


## 디버그 이동 등 순간이동 (보간 끊기)
func teleport(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	reset_physics_interpolation()


func _update_visual(input: InputFrame) -> void:
	if _shoot_anim_ticks > 0:
		_shoot_anim_ticks -= 1
	var anim: StringName = &"idle"
	if state == State.DODGE:
		anim = &"dodge"
		_sprite.flip_h = dodge.direction().x < 0.0
	elif state == State.DASH_SLASH:
		anim = &"melee"
		_sprite.flip_h = _dash_dir.x < 0.0
	else:
		_sprite.flip_h = aim_dir.x < 0.0
		if hurt_invuln_left > data.hurt_invuln_ticks - HURT_ANIM_TICKS:
			anim = &"hurt"
		elif melee.is_active():
			anim = &"melee"
		elif _shoot_anim_ticks > 0:
			anim = &"shoot"
		elif input.move != Vector2.ZERO:
			anim = &"move"
	if _sprite.animation != anim:
		_sprite.play(anim)
	# 투명: 푸르스름하게 거의 안 보이게 깜빡임 / 회피 무적: 반투명 / 피격 후 무적: 깜빡임
	if is_stealthed():
		var flicker := 0.25 + 0.1 * float((Game.tick / 4) % 2)
		_sprite.modulate = Color(0.6, 0.9, 1.0, flicker)
	elif dodge.is_invulnerable():
		_sprite.modulate = Color(1, 1, 1, 0.6)
	elif hurt_invuln_left > 0:
		_sprite.modulate = Color(1, 1, 1, 0.3 if (Game.tick / 3) % 2 == 0 else 1.0)
	else:
		_sprite.modulate = Color.WHITE
	_update_aura()
	# 회피·돌진 잔상 (화면 표시)
	if (state == State.DODGE or state == State.DASH_SLASH) and Game.tick % maxi(DB.feel.afterimage_interval_ticks, 1) == 0:
		var tint := Color(1.0, 0.8, 0.4) if state == State.DASH_SLASH else Color(0.6, 0.85, 1.0)
		AfterImage.spawn(_sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame),
			global_position, _sprite.flip_h, DB.feel.afterimage_fade_seconds, tint)


## 콤보 단계 이펙트: 단계가 오를수록 크고 진하게 (노랑 → 주황 → 흰빛). 숫자 표시 없음
func _update_aura() -> void:
	var stage := combo.stage
	_aura.visible = stage > 0
	if stage <= 0:
		return
	var colors := [Color(1.0, 0.85, 0.35, 0.55), Color(1.0, 0.55, 0.25, 0.75), Color(1.0, 1.0, 1.0, 0.9)]
	_aura.modulate = colors[clampi(stage - 1, 0, colors.size() - 1)]
	_aura.scale = Vector2.ONE * (1.0 + 0.25 * stage)
	_aura.speed_scale = 1.0 + 0.5 * stage
