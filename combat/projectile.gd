class_name Projectile
extends Node2D
## 탄. 매 틱 직접 이동하고, 물리 쿼리로 겹침을 즉시 검사한다 (신호 지연 없이 결정론적으로).
## 판정 순서 (적 탄): 근접 판정(패링) → 플레이어 피격 → 벽
##             (플레이어 탄): 적 피격 → 벽

const GROUP_ENEMY := &"enemy_projectiles"
const GROUP_PLAYER := &"player_projectiles"
const MAX_RESULTS := 16

var team: int = Team.ENEMY
var velocity: Vector2 = Vector2.ZERO
var damage: int = 0
var radius: float = 2.0
var pierce: bool = false
var lifetime: int = 60
## 반사될 때의 수명 (재패링 때 다시 채운다)
var _reflect_lifetime: int = 0
var kind: HitInfo.Kind = HitInfo.Kind.BULLET
## 완벽 패링으로 강화된 반사탄인지
var perfect: bool = false
## 반사된 횟수 (1 = 첫 반사, 2~ = 재패링 연쇄)
var reflect_count: int = 0
## 마지막으로 이 탄을 친 근접 휘두르기 번호
var last_swing_id: int = -1
var alive: bool = true

var _shape := CircleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()
var _sprite: AnimatedSprite2D
## 진행 방향으로 돌려 그리는지 / 꼬리 잔상 간격 (bullets.json 의 rotate·trail, 화면 표시 전용)
var _rotate: bool = false
var _trail_every: int = 0
var _age: int = 0
static var _bullet_meta: Dictionary = {}
## 이미 처리한 피격 영역 (관통 탄이 같은 대상을 여러 번 때리지 않게)
var _done: Dictionary = {}


## 탄을 만들어 container 에 넣는다
static func spawn(container: Node, team_value: int, pos: Vector2, dir: Vector2, data: ProjectileData) -> Projectile:
	var p := Projectile.new()
	p.team = team_value
	p.position = pos
	p.velocity = dir.normalized() * data.speed
	p.damage = data.damage
	p.radius = data.radius
	p.lifetime = data.lifetime_ticks
	p._set_anim(data.anim)
	container.add_child(p)
	return p


func _ready() -> void:
	_shape.radius = radius
	_query.shape = _shape
	_query.collide_with_areas = true
	_query.collide_with_bodies = true
	_update_group()


func _set_anim(anim: StringName) -> void:
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = DB.theme.load_sheet("bullets")
		add_child(_sprite)
	_sprite.play(anim)
	if _bullet_meta.is_empty():
		_bullet_meta = DB.theme.load_json("bullets")
	_rotate = (_bullet_meta.get("rotate", []) as Array).has(String(anim))
	_trail_every = int((_bullet_meta.get("trail", {}) as Dictionary).get(String(anim), 0))
	_update_sprite_rotation()


func _update_group() -> void:
	if team == Team.ENEMY:
		remove_from_group(GROUP_PLAYER)
		add_to_group(GROUP_ENEMY)
	else:
		remove_from_group(GROUP_ENEMY)
		add_to_group(GROUP_PLAYER)


func _physics_process(_delta: float) -> void:
	if not alive:
		return
	position += velocity / float(Game.config.tick_rate)
	_age += 1
	_update_sprite_rotation()
	if _trail_every > 0 and _age % _trail_every == 0:
		_leave_trail()
	lifetime -= 1
	if lifetime <= 0:
		destroy(false)
		return
	_check_collisions()
	if Debug.show_hitboxes:
		queue_redraw()


func _check_collisions() -> void:
	# 적 탄: 패링 / 반사탄: (숨은 테크) 재패링
	if team == Team.ENEMY or kind == HitInfo.Kind.REFLECT:
		for hitbox: Hitbox in _find(Layers.PLAYER_ATTACK, Hitbox):
			if hitbox.try_parry(self):
				return  # 반사됨: 이번 틱은 여기까지
	var hurt_layer := Layers.PLAYER_HURTBOX if team == Team.ENEMY else Layers.ENEMY_HURTBOX
	for hurtbox: Hurtbox in _find(hurt_layer, Hurtbox):
		var id := hurtbox.get_instance_id()
		if _done.has(id):
			continue
		_done[id] = true
		var hit := HitInfo.make(damage, kind, team, velocity.normalized(), self)
		hit.perfect = perfect
		if hurtbox.receive_hit(hit) == Hurtbox.Result.HIT:
			# 적을 맞히면 불꽃 (관통 탄은 지나가며 매번), 플레이어가 맞으면 작은 섬광
			var fx: StringName = &"hit_enemy" if team == Team.PLAYER else &"hit"
			if not pierce:
				destroy(true, fx)
				return
			Effect.spawn(fx, global_position)
	if not _find(Layers.WORLD, Node).is_empty():
		destroy(true, &"hit_wall")


## mask 레이어에서 겹친 것 중 type 인 것만, 위치 순으로 정렬해 돌려준다 (결정론)
func _find(mask: int, type: Variant) -> Array:
	_query.transform = Transform2D(0.0, global_position)
	_query.collision_mask = mask
	var found: Array = []
	for r: Dictionary in get_world_2d().direct_space_state.intersect_shape(_query, MAX_RESULTS):
		var col: Object = r.get("collider")
		if col != null and is_instance_of(col, type):
			found.append(col)
	if found.size() > 1:
		found.sort_custom(func(a: Node, b: Node) -> bool:
			var pa: Vector2 = (a as Node2D).global_position if a is Node2D else Vector2.ZERO
			var pb: Vector2 = (b as Node2D).global_position if b is Node2D else Vector2.ZERO
			return pa.x < pb.x or (pa.x == pb.x and pa.y < pb.y))
	return found


## 패링으로 반사: 플레이어 탄이 되어 dir 방향으로 날아간다
func reflect(dir: Vector2, is_perfect: bool, parry: ParryData) -> void:
	team = Team.PLAYER
	reflect_count += 1
	perfect = is_perfect
	kind = HitInfo.Kind.REFLECT
	velocity = dir.normalized() * velocity.length() * parry.reflect_speed_mult
	damage = parry.reflect_damage
	lifetime = parry.reflect_lifetime_ticks
	_reflect_lifetime = lifetime
	if is_perfect:
		damage = roundi(damage * parry.perfect_damage_mult)
		radius *= parry.perfect_radius_mult
		_shape.radius = radius
		pierce = parry.perfect_pierce
		_set_anim(&"reflect_perfect")
	else:
		_set_anim(&"reflect")
	_done.clear()
	_update_group()


## (숨은 테크 2) 재패링: 조준 방향으로 다시 날리며 강화. 단계가 오를수록 커지고 밝아진다
func rechain(dir: Vector2, tech: AdvancedTechData) -> void:
	reflect_count += 1
	damage += tech.reparry_damage_bonus
	velocity = dir.normalized() * velocity.length() * tech.reparry_speed_mult
	radius += tech.reparry_radius_bonus
	_shape.radius = radius
	lifetime = _reflect_lifetime if _reflect_lifetime > 0 else DB.parry.reflect_lifetime_ticks
	_done.clear()
	_set_anim(&"reflect_perfect")
	if _sprite:
		_sprite.scale = Vector2.ONE * (1.0 + 0.25 * (reflect_count - 1))
	Effect.spawn(&"perfect", global_position, 0.0, 1.0 + 0.5 * reflect_count)


## 그림을 진행 방향으로 돌린다 (회전하는 탄만)
func _update_sprite_rotation() -> void:
	if _sprite and _rotate and velocity != Vector2.ZERO:
		_sprite.rotation = velocity.angle()


## 꼬리 잔상 (화면 표시 전용)
func _leave_trail() -> void:
	var tex := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	AfterImage.spawn(tex, global_position, false, DB.feel.bullet_trail_fade_seconds, Color(1, 1, 1, 0.8),
		_sprite.rotation, _sprite.scale * 0.8)


## 없앤다 (show_effect: 맞은 자리 이펙트)
func destroy(show_effect: bool, effect: StringName = &"hit") -> void:
	if not alive:
		return
	alive = false
	if show_effect:
		Effect.spawn(effect, global_position, velocity.angle())
	queue_free()


func _draw() -> void:
	if Debug.show_hitboxes:
		draw_circle(Vector2.ZERO, radius, DebugShapes.COLOR_HITBOX)
