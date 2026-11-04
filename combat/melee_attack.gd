class_name MeleeAttack
extends Node2D
## 근접 공격 = 패링. 판정이 켜진 동안
##  - 적 피격 영역에 닿으면 데미지 (휘두를 때마다 같은 적은 한 번만)
##  - 적 탄이 닿으면 조준 방향으로 반사 (Projectile 쪽에서 Hitbox.try_parry 호출)
## 매 틱 플레이어가 tick() 을 부른다.

signal parried(projectile: Projectile, perfect: bool)
## (숨은 테크) 반사탄을 다시 쳤음
signal reparried(projectile: Projectile)

const MAX_RESULTS := 16

var data: MeleeData
var parry: ParryData
## 반사 방향 (플레이어가 매 틱 갱신)
var aim_dir: Vector2 = Vector2.RIGHT
var hitbox: Hitbox
## 데미지 배율 (연속 퍼펙트 콤보, 플레이어가 매 틱 갱신)
var damage_mult: float = 1.0
## 휘두를 때마다 1씩 오르는 번호 (같은 휘두르기로 반사탄을 두 번 치지 않게)
var swing_id: int = 0

## 판정 시작 후 지난 틱 (-1 = 비활성)
var _elapsed: int = -1
var _recovery: int = 0
var _hit_ids: Dictionary = {}
var _query := PhysicsShapeQueryParameters2D.new()


func _init(melee_data: MeleeData, parry_data: ParryData) -> void:
	data = melee_data
	parry = parry_data


func _ready() -> void:
	hitbox = Hitbox.new()
	hitbox.collision_layer = Layers.PLAYER_ATTACK
	hitbox.set_circle(data.radius)
	hitbox.parry_handler = _try_parry
	add_child(hitbox)
	hitbox.set_active(false)
	_query.shape = hitbox.shape_node.shape
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	_query.collision_mask = Layers.ENEMY_HURTBOX


func is_active() -> bool:
	return _elapsed >= 0


func can_start() -> bool:
	return not is_active() and _recovery <= 0


## 판정 시작 후 지난 틱 (비활성이면 -1)
func elapsed_ticks() -> int:
	return _elapsed


func start(dir: Vector2) -> void:
	_elapsed = 0
	swing_id += 1
	_hit_ids.clear()
	position = dir * data.offset
	hitbox.set_active(true)
	Effect.spawn(&"slash", global_position, dir.angle())


func cancel() -> void:
	if is_active():
		_finish()


## 한 틱 진행. 이번 틱에 새로 맞힌 적 수를 돌려준다
func tick() -> int:
	if not is_active():
		if _recovery > 0:
			_recovery -= 1
		return 0
	var hits := _hit_enemies()
	_elapsed += 1
	if _elapsed >= data.active_ticks:
		_finish()
	return hits


func _finish() -> void:
	_elapsed = -1
	_recovery = data.recovery_ticks
	hitbox.set_active(false)


func _hit_enemies() -> int:
	_query.transform = Transform2D(0.0, global_position)
	var targets: Array[Hurtbox] = []
	for r: Dictionary in get_world_2d().direct_space_state.intersect_shape(_query, MAX_RESULTS):
		var col: Object = r.get("collider")
		if col is Hurtbox and not _hit_ids.has(col.get_instance_id()):
			targets.append(col)
	targets.sort_custom(func(a: Hurtbox, b: Hurtbox) -> bool:
		return a.global_position.x < b.global_position.x \
			or (a.global_position.x == b.global_position.x and a.global_position.y < b.global_position.y))
	var count := 0
	var dir := position.normalized()
	for hurtbox in targets:
		_hit_ids[hurtbox.get_instance_id()] = true
		var hit := HitInfo.make(ceili(data.damage * damage_mult), HitInfo.Kind.MELEE, Team.PLAYER, dir, get_parent())
		if hurtbox.receive_hit(hit) == Hurtbox.Result.HIT:
			count += 1
	return count


## 패링 처리. 판정 시작 후 perfect_window_ticks 안이면 완벽 패링
func _try_parry(projectile: Projectile) -> bool:
	if not is_active():
		return false
	if projectile.team == Team.PLAYER:
		return _try_reparry(projectile)
	if projectile.team != Team.ENEMY:
		return false
	# _elapsed 는 이번 틱 tick() 에서 이미 1 올라가 있다 → 누른 틱에 닿으면 1
	var perfect := _elapsed <= parry.perfect_window_ticks
	projectile.reflect(aim_dir, perfect, parry)
	projectile.damage = ceili(projectile.damage * damage_mult)
	projectile.last_swing_id = swing_id
	parried.emit(projectile, perfect)
	return true


## (숨은 테크 2) 반사탄 재패링: 새로 휘두른 근접으로 반사탄을 다시 치면 연쇄 강화
func _try_reparry(projectile: Projectile) -> bool:
	var tech := DB.advanced
	if projectile.kind != HitInfo.Kind.REFLECT or projectile.last_swing_id == swing_id:
		return false
	if projectile.reflect_count > tech.reparry_max_chain:
		return false
	projectile.rechain(aim_dir, tech)
	projectile.last_swing_id = swing_id
	reparried.emit(projectile)
	return true
