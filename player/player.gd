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
## 스킬2 (F, 스토리판에서 칸이 열린 뒤)
var skill2: Skill
## 장착한 무기의 전투 수치 (사격·근접·패링). Loadout 에서 읽는다
var weapon: WeaponData
## 장착 효과가 반영된 수치 (apply_loadout 에서 계산)
var _move_speed: float = 0.0
var _hurt_invuln_ticks: int = 0
var _ranged_mult: float = 1.0
var _melee_mult: float = 1.0
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
## 등 뒤 망토 층: 움직임을 스프링으로 따라가며 휘날림 (화면 표시 전용)
var _cloak: AnimatedSprite2D
var _cloak_lean: float = 0.0
var _cloak_vel: float = 0.0
## 몸 그림의 프레임별 상체 이동 (player.json 의 body_offsets) — 망토를 같이 움직인다
var _body_offsets: Dictionary = {}

## 보는 방향에 따른 그림 (옆모습 / 정면 / 뒷모습). 화면 표시 전용
enum View { SIDE, FRONT, BACK }
const VIEW_SHEETS := {
	View.SIDE: ["player", "player_cloak"],
	View.FRONT: ["player_front", "player_cloak_front"],
	View.BACK: ["player_back", "player_cloak_back"],
}
var view: View = View.SIDE
## 떠 있는 총 (손 없이 총만, 캐릭터 둘레에서 조준 방향으로 돈다). 화면 표시 전용
var _gun: AnimatedSprite2D
## 총이 어깨에서 마우스 쪽을 향하는 방향 (사격 방향과 같음)
var _shot_dir: Vector2 = Vector2.RIGHT
## 총구 불꽃 (총에 붙어 같이 돈다) / 반동으로 뒤로 밀린 거리 (px)
var _muzzle_flash: AnimatedSprite2D
var _muzzle: Vector2 = Vector2.ZERO
## 터치 조작(모바일)일 때만: 지금 조준하는 방향을 보여주는 작은 조준점 (캐릭터에서 살짝 띄움, 화면 표시 전용)
var _aim_marker: Sprite2D
var _gun_kick: float = 0.0
## 방향별 [몸 SpriteFrames, 망토 SpriteFrames, body_offsets]
var _view_res: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)
	data = DB.player
	dodge = DB.dodge.create_ability()
	weapon = Loadout.weapon()
	ammo = Ammo.new(weapon.gun.magazine_size, weapon.gun.start_ammo)
	health = Health.new(data.max_hp)
	apply_loadout()
	combo = Combo.new(DB.advanced)
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.ENEMY | Layers.PIT
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_build_children()
	Events.player_spawned.emit(self)


## 장착(무기·갑옷)에서 전투 수치를 다시 읽는다. 시작할 때와 장착이 바뀔 때 부른다
func apply_loadout() -> void:
	weapon = Loadout.weapon()
	gun = Gun.new(weapon.gun)
	ammo.set_maximum(weapon.gun.magazine_size)
	health.set_maximum(roundi(Loadout.stat("max_hp", data.max_hp)))
	_move_speed = Loadout.stat("move_speed", data.move_speed)
	_hurt_invuln_ticks = roundi(Loadout.stat("hurt_invuln_ticks", data.hurt_invuln_ticks))
	_ranged_mult = Loadout.stat("ranged_damage", 1.0)
	_melee_mult = Loadout.stat("melee_damage", 1.0)
	if melee != null:
		melee.set_data(weapon.melee, weapon.parry)
	Events.player_hp_changed.emit(health.current, health.maximum)


func _build_children() -> void:
	var body_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = data.body_radius
	body_shape.shape = circle
	body_shape.position = Vector2(0, data.body_offset_y)
	add_child(body_shape)

	for v: View in VIEW_SHEETS:
		var names: Array = VIEW_SHEETS[v]
		var meta := DB.theme.load_json(names[0])
		var sh: Array = meta.get("shoulder", [8.0, 12.0])
		_view_res[v] = [DB.theme.load_sheet(names[0]), DB.theme.load_sheet(names[1]),
			meta.get("body_offsets", {}), Vector2(float(sh[0]), float(sh[1]))]
	# 망토는 몸보다 먼저 추가 → 몸 뒤에 그려진다 (뒷모습일 때만 몸 앞으로 옮김)
	_cloak = AnimatedSprite2D.new()
	_cloak.sprite_frames = _view_res[View.SIDE][1]
	_cloak.play(&"cloak_hang")
	add_child(_cloak)
	_body_offsets = _view_res[View.SIDE][2]

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _view_res[View.SIDE][0]
	_sprite.offset = SpriteSheet.foot_offset(_sprite.sprite_frames)
	_sprite.play(&"idle")
	add_child(_sprite)

	_gun = AnimatedSprite2D.new()
	_gun.sprite_frames = DB.theme.load_sheet("gun")
	_gun.centered = false
	var pivot: Array = DB.theme.load_json("gun").get("pivot", [0.0, 0.0])
	_gun.offset = -Vector2(float(pivot[0]), float(pivot[1]))
	_gun.play(&"idle")
	add_child(_gun)
	if TouchControls.is_enabled():
		_aim_marker = Sprite2D.new()
		_aim_marker.texture = DB.theme.load_texture("crosshair")
		_aim_marker.modulate.a = DB.touch.aim_marker_alpha
		_aim_marker.z_index = 5
		add_child(_aim_marker)
	var gun_meta := DB.theme.load_json("gun")
	var muzzle: Array = gun_meta.get("muzzle", [0.0, 0.0])
	_muzzle = Vector2(float(muzzle[0]), float(muzzle[1])) - Vector2(float(pivot[0]), float(pivot[1]))
	_muzzle_flash = AnimatedSprite2D.new()
	_muzzle_flash.sprite_frames = DB.theme.load_sheet("muzzle_flash")
	_muzzle_flash.centered = false
	var origin: Array = DB.theme.load_json("muzzle_flash").get("origin", [0.0, 0.0])
	_muzzle_flash.offset = -Vector2(float(origin[0]), float(origin[1]))
	_muzzle_flash.visible = false
	_muzzle_flash.animation_finished.connect(func() -> void: _muzzle_flash.visible = false)
	_gun.add_child(_muzzle_flash)

	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = Layers.PLAYER_HURTBOX
	_hurtbox.set_circle(data.hurtbox_radius, Vector2(0, data.hurtbox_offset_y))
	_hurtbox.handler = _on_hurt
	add_child(_hurtbox)

	melee = MeleeAttack.new(weapon.melee, weapon.parry)
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
		_update_cloak()
		_update_gun()
		return
	if cutscene_lock:
		velocity = Vector2.ZERO
		if _sprite.animation != &"idle":
			_sprite.play(&"idle")
		_sprite.modulate = Color.WHITE
		_update_cloak()
		_update_gun()
		return
	_update_aim(input)
	melee.aim_dir = aim_dir
	combo.tick()
	melee.damage_mult = combo.damage_mult() * _melee_mult
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
	if skill2:
		skill2.tick()
	var hits := melee.tick()
	if hits > 0:
		ammo.add(hits * weapon.melee.ammo_on_hit)
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
	if input.is_pressed(InputFrame.SKILL2) and skill2:
		skill2.try_use()
	if input.is_pressed(InputFrame.MELEE) and melee.can_start():
		melee.start(aim_dir)
		Events.melee_started.emit()
	elif input.is_held(InputFrame.SHOOT) and not melee.is_active():
		_try_shoot(input)
	var speed := _move_speed * combo.speed_mult()
	if melee.is_active():
		speed *= weapon.melee.move_speed_mult
	velocity = input.move * speed


func _try_shoot(input: InputFrame) -> void:
	if ammo.current <= 0:
		if input.is_pressed(InputFrame.SHOOT):
			Events.ammo_empty.emit()
		return
	var container := get_tree().get_first_node_in_group(Level.GROUP_PROJECTILES)
	# 어깨 높이에서 마우스 쪽으로 쏜다 (총구에서 탄이 나가 보이게)
	if gun.try_fire(ammo, container, _shot_origin(), _shot_dir, combo.damage_mult() * _ranged_mult):
		_shoot_anim_ticks = weapon.gun.fire_interval_ticks
		_gun_kick = DB.feel.gun_recoil_px
		_muzzle_flash.visible = true
		_muzzle_flash.play(&"flash")
		_muzzle_flash.frame = 0
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
	melee.position = _dash_dir * weapon.melee.offset
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
	var to_shot := input.aim - _shot_origin()
	_shot_dir = to_shot.normalized() if to_shot.length_squared() > 1.0 else aim_dir


## 탄이 나가는 기준점 (어깨 높이)
func _shot_origin() -> Vector2:
	return global_position + Vector2(0.0, -weapon.gun.muzzle_height)


## 지금 무적인지 (회피 무적, 피격 후 무적, 디버그 무적)
func is_invulnerable() -> bool:
	return Debug.god_mode or cutscene_lock or dodge.is_invulnerable() or hurt_invuln_left > 0 \
		or (state == State.DASH_SLASH and DB.advanced.dash_slash_invuln) \
		or (skill != null and skill.grants_invulnerability()) \
		or (skill2 != null and skill2.grants_invulnerability())


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
		hurt_invuln_left = _hurt_invuln_ticks
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
	_set_view(View.SIDE)  # 쓰러지는 그림은 옆모습에만 있음
	_sprite.modulate = Color.WHITE
	_sprite.play(&"death")


## 컷씬: 쓰러졌던 자리에서 다시 일어남 (스토리판 프롤로그). 체력은 다시 가득
func cutscene_wake() -> void:
	state = State.NORMAL
	velocity = Vector2.ZERO
	health.current = health.maximum
	Events.player_hp_changed.emit(health.current, health.maximum)


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


## 스킬2(F) 칸에 스킬을 넣는다 (null = 비움)
func set_skill2(data: SkillData) -> void:
	if skill2:
		skill2.cleanup()
		skill2.queue_free()
		skill2 = null
	if data == null:
		return
	skill2 = data.create_skill()
	skill2.player = self
	add_child(skill2)


func _exit_tree() -> void:
	if skill:
		skill.cleanup()
	if skill2:
		skill2.cleanup()


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	_set_view(View.SIDE)  # 쓰러지는 그림은 옆모습에만 있음
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
	ammo.add(weapon.parry.ammo_on_parry)
	Events.parried.emit(perfect)
	Effect.spawn(&"hit_parry", projectile.global_position, 0.0, 1.5)
	if perfect:
		combo.add()
		Effect.spawn(&"perfect", projectile.global_position, 0.0, 2.0)


func _on_reparried(projectile: Projectile) -> void:
	ammo.add(weapon.parry.ammo_on_parry)
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
	var look := aim_dir
	if state == State.DODGE:
		anim = &"dodge"
		look = dodge.direction()
	elif state == State.DASH_SLASH:
		anim = &"melee"
		look = _dash_dir
	else:
		if hurt_invuln_left > data.hurt_invuln_ticks - HURT_ANIM_TICKS:
			anim = &"hurt"
		elif melee.is_active():
			anim = &"melee"
		elif _shoot_anim_ticks > 0:
			anim = &"shoot"
		elif input.move != Vector2.ZERO:
			anim = &"move"
	_set_view(_choose_view(look))
	if view == View.SIDE and look.x != 0.0:
		_sprite.flip_h = look.x < 0.0
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
	_update_cloak()
	_update_gun()
	# 회피·돌진 잔상 (화면 표시)
	if (state == State.DODGE or state == State.DASH_SLASH) and Game.tick % maxi(DB.feel.afterimage_interval_ticks, 1) == 0:
		var tint := Color(1.0, 0.8, 0.4) if state == State.DASH_SLASH else Color(0.6, 0.85, 1.0)
		AfterImage.spawn(_cloak.sprite_frames.get_frame_texture(_cloak.animation, _cloak.frame),
			global_position + _cloak.offset, _cloak.flip_h, DB.feel.afterimage_fade_seconds, tint)
		AfterImage.spawn(_sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame),
			global_position + _sprite.offset, _sprite.flip_h, DB.feel.afterimage_fade_seconds, tint)


## 보는 방향 → 그림 방향. 경계에서 깜빡이지 않게 지금 방향을 조금 더 유지한다
func _choose_view(dir: Vector2) -> View:
	if dir == Vector2.ZERO:
		return view
	var f := DB.feel
	var ax := absf(dir.x)
	var ay := absf(dir.y)
	var keep := 1.0 + f.view_hysteresis
	var vertical: bool
	if view == View.SIDE:
		vertical = ay > ax * f.view_switch_ratio * keep
	else:
		vertical = ay * keep >= ax * f.view_switch_ratio
	if not vertical:
		return View.SIDE
	return View.BACK if dir.y < 0.0 else View.FRONT


## 그림 방향을 바꾼다 (지금 애니메이션·프레임은 그대로 이어서)
func _set_view(v: View) -> void:
	if v == view:
		return
	view = v
	var res: Array = _view_res[v]
	var anim := _sprite.animation
	var frame := _sprite.frame
	var progress := _sprite.frame_progress
	_sprite.sprite_frames = res[0]
	_sprite.play(anim)
	_sprite.set_frame_and_progress(frame, progress)
	if v != View.SIDE:
		_sprite.flip_h = false
	var cloak_anim := _cloak.animation
	var cloak_frame := _cloak.frame
	_cloak.sprite_frames = res[1]
	_cloak.play(cloak_anim)
	_cloak.frame = cloak_frame
	_body_offsets = res[2]
	_apply_draw_order()


## 그리는 순서: 뒷모습이면 총(몸 뒤) → 몸 → 목도리 꼬리(등 위), 아니면 꼬리 → 몸 → 총
func _apply_draw_order() -> void:
	var order: Array = [_gun, _sprite, _cloak] if view == View.BACK else [_cloak, _sprite, _gun]
	var first := mini(_cloak.get_index(), mini(_sprite.get_index(), _gun.get_index()))
	for i in order.size():
		move_child(order[i] as Node, first + i)


## 총: 캐릭터 둘레에 떠서 사격 방향으로 돈다 (그림 하나를 통째로 돌림). 회피·근접·사망 중에는 숨김 (화면 표시 전용)
func _update_gun() -> void:
	_update_aim_marker()
	# 스토리판: 근접 공격은 들고 있는 총으로 후려치는 동작 → 휘두르는 동안 총이 호를 그리며 돈다
	var swinging := Game.is_story_mode() and melee.is_active() and state == State.NORMAL
	var hidden_now := state == State.DODGE or state == State.DASH_SLASH or state == State.DEAD \
		or (melee.is_active() and not swinging) or _sprite.animation == &"death"
	_gun.visible = not hidden_now
	if hidden_now:
		return
	if swinging:
		var t := clampf(float(melee.elapsed_ticks()) / float(maxi(weapon.melee.active_ticks, 1)), 0.0, 1.0)
		var arc := deg_to_rad(DB.feel.gun_swing_arc_deg)
		var swing_dir := melee.position.normalized().rotated(lerpf(-arc * 0.5, arc * 0.5, t))
		_gun.position = Vector2(0.0, -weapon.gun.muzzle_height) + swing_dir * DB.feel.gun_swing_reach
		_gun.rotation = swing_dir.angle()
		_gun.flip_v = swing_dir.x < 0.0
		_gun.modulate = _sprite.modulate
		return
	# 총은 손에 들지 않고 가슴 높이 둘레에 떠서 조준 방향에 머문다. 살짝 위아래로 떠다님
	var f := DB.feel
	var hover := sin(TAU * float(Game.tick) / maxf(f.gun_hover_period_ticks, 1.0)) * f.gun_hover_px
	_gun.position = Vector2(0.0, -weapon.gun.muzzle_height + hover) + _shot_dir * (f.gun_orbit_radius - _gun_kick)
	_gun_kick *= DB.feel.gun_recoil_return
	_gun.rotation = _shot_dir.angle()
	_gun.flip_v = _shot_dir.x < 0.0
	_gun.modulate = _sprite.modulate
	_muzzle_flash.position = Vector2(_muzzle.x, -_muzzle.y if _gun.flip_v else _muzzle.y)


## 그림이 향한 방향 (망토가 뒤로 날리는 기준)
## 모바일 조준점: 총 높이에서 조준 방향으로 aim_marker_distance 만큼 떨어진 곳
func _update_aim_marker() -> void:
	if _aim_marker == null:
		return
	_aim_marker.visible = state != State.DEAD and not cutscene_lock
	_aim_marker.position = (Vector2(0.0, -weapon.gun.muzzle_height) + aim_dir.normalized() * DB.touch.aim_marker_distance).round()


func _facing_vector() -> Vector2:
	match view:
		View.FRONT:
			return Vector2.DOWN
		View.BACK:
			return Vector2.UP
	return Vector2.LEFT if _sprite.flip_h else Vector2.RIGHT


## 망토 기울기 단계 (-1 앞으로 쏠림 ~ 3 펄럭) → 애니메이션 이름
const CLOAK_ANIMS: Array[StringName] = [&"cloak_fwd", &"cloak_hang", &"cloak_trail1", &"cloak_trail2", &"cloak_billow"]


## 망토: 이동 속도·방향을 스프링으로 따라간다. 멈추면 한 번 앞으로 출렁였다가 늘어짐 (화면 표시 전용)
func _update_cloak() -> void:
	var f := DB.feel
	var face := _facing_vector()
	var target := 0.0
	if state == State.DODGE or state == State.DASH_SLASH:
		target = f.cloak_dodge_lean
	elif state != State.DEAD and not cutscene_lock:
		var run := maxf(data.move_speed, 1.0)
		var along := velocity.dot(face) / run      # +: 보는 쪽으로 달림 → 뒤로 날림
		var vertical := absf(velocity.cross(face)) / run   # 옆으로 움직임
		if along >= 0.0:
			target = along * f.cloak_run_lean
		else:
			target = -along * f.cloak_backpedal_lean
		target += vertical * f.cloak_vertical_factor * f.cloak_run_lean
	_cloak_vel += (target - _cloak_lean) * f.cloak_stiffness
	_cloak_vel *= 1.0 - f.cloak_damping
	_cloak_lean += _cloak_vel
	var idx := clampi(roundi(_cloak_lean) + 1, 0, CLOAK_ANIMS.size() - 1)
	if _cloak.animation != CLOAK_ANIMS[idx]:
		_cloak.play(CLOAK_ANIMS[idx])
	# 몸 기준 위치에 붙인다 (망토 그림은 뒤쪽으로 8px 넓음)
	var half_extra := (_cloak.sprite_frames.get_frame_texture(_cloak.animation, 0).get_width() - 16) * 0.5
	_cloak.flip_h = _sprite.flip_h
	var body := _body_offset()
	if view == View.SIDE:
		var facing := face.x
		_cloak.offset = Vector2(-half_extra * facing + body.x * facing, _sprite.offset.y + body.y)
	else:
		_cloak.offset = Vector2(body.x, _sprite.offset.y + body.y)   # 정면·뒷모습: 가운데 정렬
	_cloak.modulate = _sprite.modulate
	if _sprite.animation == &"hurt":
		_cloak.modulate = Color(1, 0.55, 0.55) if _sprite.frame == 1 else Color(1.6, 1.6, 1.6)
	# 쓰러져 누우면 망토는 누운 그림에 포함되어 있으므로 숨김
	_cloak.visible = not (_sprite.animation == &"death" and _sprite.frame >= 2)


## 지금 몸 그림 프레임의 상체 이동 (웅크림·튀어 오름·달리기 기울기). 망토도 같이 움직인다
func _body_offset() -> Vector2:
	var list: Array = _body_offsets.get(String(_sprite.animation), [])
	if _sprite.frame < list.size():
		var o: Array = list[_sprite.frame]
		return Vector2(float(o[0]), float(o[1]))
	return Vector2.ZERO


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
