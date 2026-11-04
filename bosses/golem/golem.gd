class_name Golem
extends Enemy
## 탄막 골렘 (미니 보스, 맵 글자 'Z'). 2페이즈 보스이며 본편에서 재등장한다.
## - 7구간에 들어오면 깨어나 1페이즈 시작
## - 몸통은 일반 탄·근접에 거의 피해를 받지 않는다 (body_hits_per_damage 번에 1)
## - 반사탄(패링한 탄)은 코어에 제대로 들어간다 → 패링이 핵심
## - 완벽 패링 반사탄을 연속으로 맞히면 그로기 → 모든 공격이 크게 들어가는 딜 구간
## - 체력 0 → Events.boss_defeated (타이머 정지) → 2페이즈 시작 컷씬 (GolemCutscene)

enum Mode { DORMANT, INTRO, FIGHT, GROGGY, CUTSCENE }

var mode: Mode = Mode.DORMANT
var phase: GolemPhase
## 1페이즈를 깼는지
var defeated: bool = false
## 그로기까지 쌓인 연속 완벽 반사 수
var perfect_chain: int = 0

var _timer: int = 0
var _body_hits: int = 0
var _last_perfect_tick: int = -100000
var _core_flash: int = 0


func gd() -> GolemData:
	return data as GolemData


func _on_ready() -> void:
	Events.section_entered.connect(_on_section_entered)


func _on_section_entered(index: int) -> void:
	if index == 7 and mode == Mode.DORMANT:
		wake()


## 깨어남 (7구간 입장 시)
func wake() -> void:
	if mode != Mode.DORMANT:
		return
	mode = Mode.INTRO
	_timer = gd().intro_ticks
	has_target = true
	Events.boss_started.emit(self)
	Events.boss_hp_changed.emit(hp, gd().max_hp)


func enter_phase(p: GolemPhase) -> void:
	phase = p
	phase.enter()


func _tick_ai() -> void:
	velocity = Vector2.ZERO
	match mode:
		Mode.INTRO:
			_timer -= 1
			if _timer <= 0:
				mode = Mode.FIGHT
				enter_phase(GolemPhase1.new(self))
		Mode.FIGHT:
			phase.tick()
		Mode.GROGGY:
			_timer -= 1
			if _timer <= 0:
				mode = Mode.FIGHT
				phase.enter()


## 탄 한 발 (몸 중심에서 dir 쪽)
func fire(dir: Vector2) -> void:
	var container := get_tree().get_first_node_in_group(Level.GROUP_PROJECTILES)
	if container:
		Projectile.spawn(container, Team.ENEMY, global_position + dir * gd().muzzle_offset, dir, gd().projectile)


func apply_knockback(_knock_velocity: Vector2, _ticks: int) -> void:
	pass  # 골렘은 밀리지 않는다


func is_groggy() -> bool:
	return mode == Mode.GROGGY


func _on_hurt(hit: HitInfo) -> Hurtbox.Result:
	if dead or defeated or mode == Mode.CUTSCENE:
		return Hurtbox.Result.IGNORED
	if mode == Mode.DORMANT:
		return Hurtbox.Result.HIT  # 깨기 전엔 맞아도 무시 (탄은 막음)
	var d := gd()
	var damage := 0
	if mode == Mode.GROGGY:
		damage = ceili(hit.damage * d.groggy_damage_mult)
		_core_flash = HURT_FLASH_TICKS
	elif hit.kind == HitInfo.Kind.REFLECT:
		damage = ceili(hit.damage * d.core_damage_mult)
		_core_flash = HURT_FLASH_TICKS
		_count_perfect(hit.perfect)
	elif hit.kind == HitInfo.Kind.EXECUTE:
		# (숨은 테크) 은신 처형은 코어에 직접 들어간다
		damage = hit.damage
		_core_flash = HURT_FLASH_TICKS
	else:
		_body_hits += 1
		if _body_hits >= d.body_hits_per_damage:
			_body_hits = 0
			damage = 1
		_hurt_flash = HURT_FLASH_TICKS
	if mark_left > 0 and damage > 0:
		damage = ceili(damage * mark_mult)
	if damage > 0:
		hp = maxi(hp - damage, 0)
		Events.enemy_damaged.emit(self, hit)
		Events.boss_hp_changed.emit(hp, d.max_hp)
	if hp <= 0:
		_defeat()
	return Hurtbox.Result.HIT


func _count_perfect(perfect: bool) -> void:
	if not perfect:
		perfect_chain = 0
		return
	if Game.tick - _last_perfect_tick > gd().groggy_chain_window_ticks:
		perfect_chain = 0
	perfect_chain += 1
	_last_perfect_tick = Game.tick
	if perfect_chain >= gd().groggy_perfect_hits:
		perfect_chain = 0
		mode = Mode.GROGGY
		_timer = gd().groggy_ticks
		Events.boss_groggy.emit()
		Effect.spawn(&"perfect", global_position, 0.0, 4.0)


## 1페이즈 격파 → 타이머 정지 → 2페이즈 시작 컷씬
func _defeat() -> void:
	defeated = true
	mode = Mode.CUTSCENE
	Events.boss_defeated.emit(self)
	var cut := GolemCutscene.new(self)
	get_parent().add_child(cut)


## 컷씬이 끝난 뒤 (데모가 아닐 때) 2페이즈 전투 시작
func start_phase2() -> void:
	defeated = false
	hp = gd().max_hp
	mode = Mode.FIGHT
	enter_phase(GolemPhase2.new(self))
	Events.boss_hp_changed.emit(hp, gd().max_hp)


func _anim() -> StringName:
	match mode:
		Mode.GROGGY:
			return &"groggy"
		Mode.CUTSCENE:
			return sprite.animation
		Mode.FIGHT:
			if phase and phase.is_attacking():
				return &"attack"
	return &"idle"


func _update_visual() -> void:
	var anim := _anim()
	if _core_flash > 0:
		_core_flash -= 1
		anim = &"core_hit"
	elif _hurt_flash > 0:
		_hurt_flash -= 1
		anim = &"hurt"
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.flip_h = false
