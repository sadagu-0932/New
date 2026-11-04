class_name TestM2
extends TestBase
## M2 자동 테스트: 사격·탄약, 근접·탄약 회복, 패링·완벽 패링, 완벽 회피·투명
## 테스트 맵: 플레이어 (40,56), 허수아비 (168,56) (216,56)

const MAP := "res://tests/maps/m2_test.txt"

var _events: Dictionary = {}


func run_all() -> void:
	print("[M2] 사격·근접·패링·완벽 판정·투명")
	var conns := [
		[Events.ammo_empty, func() -> void: _count(&"ammo_empty")],
		[Events.parried, func(perfect: bool) -> void: _count(&"perfect_parry" if perfect else &"parry")],
		[Events.perfect_dodge, func() -> void: _count(&"perfect_dodge")],
		[Events.stealth_changed, func(active: bool) -> void: _count(&"stealth_on" if active else &"stealth_off")],
		[Events.player_hit, func(_h: HitInfo) -> void: _count(&"player_hit")],
	]
	for c: Array in conns:
		(c[0] as Signal).connect(c[1])
	await test_shoot_single()
	await test_hold_fire_rate()
	await test_ammo_runs_out()
	await test_bullet_hits_dummy()
	await test_bullet_hits_wall()
	await test_melee_recovers_ammo()
	await test_parry()
	await test_perfect_parry_pierce()
	await test_enemy_bullet_hits_player()
	await test_perfect_dodge_graze()
	await test_early_dodge_not_perfect()
	await test_stealth_duration()
	await test_combat_determinism()
	for c: Array in conns:
		(c[0] as Signal).disconnect(c[1])


func _count(key: StringName) -> void:
	_events[key] = int(_events.get(key, 0)) + 1


func _ev(key: StringName) -> int:
	return int(_events.get(key, 0))


func _start() -> Player:
	await new_level(MAP)
	_events.clear()
	return level.player


func _aim_right(p: Player) -> Vector2:
	return p.global_position + Vector2(100, 0)


func _dummies() -> Array[TargetDummy]:
	var list: Array[TargetDummy] = []
	for n in level.get_node("Props").get_children():
		if n is TargetDummy:
			list.append(n)
	return list


func _projectiles(team: int) -> Array[Projectile]:
	var list: Array[Projectile] = []
	for n in level.projectiles.get_children():
		var pr := n as Projectile
		if pr and pr.alive and pr.team == team:
			list.append(pr)
	return list


## 탄이 사라졌는지 (해제된 객체를 람다에 잡지 않도록 인스턴스 ID로 확인)
func _gone(id: int) -> bool:
	var pr := instance_from_id(id) as Projectile
	return pr == null or not pr.alive


func _reflected(id: int) -> bool:
	var pr := instance_from_id(id) as Projectile
	return pr != null and pr.team == Team.PLAYER


func _enemy_bullet(from: Vector2, dir: Vector2) -> Projectile:
	return Projectile.spawn(level.projectiles, Team.ENEMY, from, dir, DB.test_turret.projectile)


func test_shoot_single() -> void:
	var p := await _start()
	input.push(Vector2.ZERO, 1, 0, InputFrame.SHOOT, _aim_right(p))
	await step(1)
	check(p.ammo.current == DB.gun.magazine_size - 1, "한 발 쏘면 탄약 -1")
	check(_projectiles(Team.PLAYER).size() == 1, "탄 1개 생성")


func test_hold_fire_rate() -> void:
	var p := await _start()
	var interval := DB.gun.fire_interval_ticks
	input.push(Vector2.ZERO, interval * 2 + 1, InputFrame.SHOOT, 0, _aim_right(p))
	await step(interval * 2 + 1)
	check(p.ammo.current == DB.gun.magazine_size - 3, "누르고 있으면 %d틱마다 연사 (3발)" % interval)


func test_ammo_runs_out() -> void:
	var p := await _start()
	p.ammo.set_current(2)
	input.push(Vector2.ZERO, 60, InputFrame.SHOOT, 0, _aim_right(p))
	await step(60)
	check(p.ammo.current == 0, "탄약 0까지 씀")
	input.push(Vector2.ZERO, 1, 0, InputFrame.SHOOT, _aim_right(p))
	await step(1)
	check(_ev(&"ammo_empty") == 1, "탄약 0에서 사격 → 빈 탄창 이벤트")
	check(p.ammo.current == 0, "자동 재장전 없음")


func test_bullet_hits_dummy() -> void:
	var p := await _start()
	var dummy := _dummies()[0]
	input.push(Vector2.ZERO, 1, 0, InputFrame.SHOOT, _aim_right(p))
	await step(1)
	await wait_until(func() -> bool: return _projectiles(Team.PLAYER).is_empty(), 60)
	check(dummy.damage_taken == DB.gun.projectile.damage, "탄이 허수아비에 명중 (데미지 %d)" % dummy.damage_taken)
	check(_dummies()[1].damage_taken == 0, "일반 탄은 관통하지 않음")


func test_bullet_hits_wall() -> void:
	var p := await _start()
	input.push(Vector2.ZERO, 1, 0, InputFrame.SHOOT, p.global_position + Vector2(0, -100))
	await step(1)
	var gone := await wait_until(func() -> bool: return _projectiles(Team.PLAYER).is_empty(), 30)
	check(gone, "위쪽 벽에 맞고 사라짐")


func test_melee_recovers_ammo() -> void:
	var p := await _start()
	var dummy := _dummies()[0]
	p.teleport(dummy.global_position - Vector2(16, 0))
	p.ammo.set_current(0)
	var aim := dummy.global_position
	input.push(Vector2.ZERO, 1, 0, InputFrame.MELEE, aim)
	await step(1)
	check(dummy.damage_taken == DB.melee.damage, "근접 명중 (데미지 %d)" % dummy.damage_taken)
	check(p.ammo.current == DB.melee.ammo_on_hit, "근접 명중 → 탄약 +%d" % DB.melee.ammo_on_hit)
	await step(DB.melee.active_ticks)
	check(dummy.hit_count == 1, "한 번 휘두를 때 같은 대상은 한 번만")
	input.push(Vector2.ZERO, 1, 0, InputFrame.MELEE, aim)
	await step(1)
	check(not p.melee.is_active(), "후딜 중에는 다시 못 휘두름")
	await step(DB.melee.recovery_ticks)
	input.push(Vector2.ZERO, 1, 0, InputFrame.MELEE, aim)
	await step(1)
	check(p.melee.is_active() and dummy.hit_count == 2, "후딜 후 다시 휘두름")


## 탄이 근접 판정에 닿기까지 남은 틱이 ticks_before 쯤일 때 근접을 누른다
func _melee_when_bullet_near(p: Player, bullet: Projectile, ticks_before: int) -> void:
	var per_tick := bullet.velocity.length() / float(Game.config.tick_rate)
	var contact := DB.melee.offset + DB.melee.radius + bullet.radius
	var trigger := contact + per_tick * ticks_before
	await wait_until(func() -> bool: return bullet.global_position.x - p.global_position.x <= trigger, 120)
	input.push(Vector2.ZERO, 1, 0, InputFrame.MELEE, _aim_right(p))


func test_parry() -> void:
	var p := await _start()
	p.ammo.set_current(0)
	var bullet := _enemy_bullet(p.global_position + Vector2(60, 0), Vector2.LEFT)
	var bid := bullet.get_instance_id()
	var speed := bullet.velocity.length()
	await step(1)
	await _melee_when_bullet_near(p, bullet, DB.parry.perfect_window_ticks + 3)
	await wait_until(func() -> bool: return _reflected(bid), 30)
	check(bullet.team == Team.PLAYER, "패링: 적 탄이 반사됨")
	check(not bullet.perfect, "판정창 밖이면 일반 패링")
	check(_ev(&"parry") == 1 and _ev(&"perfect_parry") == 0, "패링 이벤트")
	check(bullet.velocity.normalized().dot(Vector2.RIGHT) > 0.99, "조준 방향(오른쪽)으로 반사")
	check_near(bullet.velocity.length(), speed * DB.parry.reflect_speed_mult, 0.01, "반사탄 속도")
	check(p.ammo.current == DB.parry.ammo_on_parry, "패링 → 탄약 +%d" % DB.parry.ammo_on_parry)
	check(_ev(&"player_hit") == 0, "패링하면 맞지 않음")
	await wait_until(func() -> bool: return _gone(bid), 90)
	check(_dummies()[0].damage_taken == DB.parry.reflect_damage, "반사탄이 허수아비 명중")
	check(_dummies()[1].damage_taken == 0, "일반 반사탄은 관통 안 함")


func test_perfect_parry_pierce() -> void:
	var p := await _start()
	var bullet := _enemy_bullet(p.global_position + Vector2(60, 0), Vector2.LEFT)
	var bid := bullet.get_instance_id()
	var base_radius := bullet.radius
	await step(1)
	await _melee_when_bullet_near(p, bullet, 2)
	await wait_until(func() -> bool: return _reflected(bid), 30)
	check(bullet.perfect, "판정창 안이면 완벽 패링")
	check(_ev(&"perfect_parry") == 1, "완벽 패링 이벤트")
	check_near(bullet.radius, base_radius * DB.parry.perfect_radius_mult, 0.01, "완벽 반사탄 크기 증가")
	var dmg := roundi(DB.parry.reflect_damage * DB.parry.perfect_damage_mult)
	check(bullet.damage == dmg and bullet.pierce, "완벽 반사탄 데미지 %d + 관통" % dmg)
	await wait_until(func() -> bool: return _gone(bid), 120)
	var d := _dummies()
	check(d[0].damage_taken == dmg and d[1].damage_taken == dmg, "관통해서 허수아비 둘 다 명중 (%d, %d)" % [d[0].damage_taken, d[1].damage_taken])


func test_enemy_bullet_hits_player() -> void:
	var p := await _start()
	var bullet := _enemy_bullet(p.global_position + Vector2(40, 0), Vector2.LEFT)
	var bid := bullet.get_instance_id()
	await wait_until(func() -> bool: return _gone(bid), 60)
	check(_ev(&"player_hit") == 1, "가만히 있으면 적 탄에 맞음")


func test_perfect_dodge_graze() -> void:
	var p := await _start()
	var bullet := _enemy_bullet(p.global_position + Vector2(50, 0), Vector2.LEFT)
	var per_tick := bullet.velocity.length() / float(Game.config.tick_rate)
	var touch := DB.player.hurtbox_radius + bullet.radius
	# 맞기 2틱 전에 위로(탄과 수직) 회피
	await wait_until(func() -> bool: return bullet.global_position.x - p.global_position.x <= touch + per_tick * 2, 120)
	input.push(Vector2.UP, 1, 0, InputFrame.DODGE, _aim_right(p))
	await step(DB.stealth.perfect_dodge_window_ticks + 1)
	check(_ev(&"perfect_dodge") == 1, "맞기 직전 옆으로 회피 → 완벽 회피")
	check(p.is_stealthed() and _ev(&"stealth_on") == 1, "완벽 회피 → 투명")
	check(_ev(&"player_hit") == 0, "완벽 회피 중 맞지 않음")


func test_early_dodge_not_perfect() -> void:
	var p := await _start()
	_enemy_bullet(p.global_position + Vector2(120, 0), Vector2.LEFT)
	input.push(Vector2.UP, 1, 0, InputFrame.DODGE, _aim_right(p))
	await step((DB.dodge as DashDodgeData).duration_ticks)
	check(_ev(&"perfect_dodge") == 0 and not p.is_stealthed(), "탄이 멀 때 회피하면 완벽 회피 아님")


func test_stealth_duration() -> void:
	var p := await _start()
	var bullet := _enemy_bullet(p.global_position + Vector2(30, 0), Vector2.LEFT)
	var per_tick := bullet.velocity.length() / float(Game.config.tick_rate)
	await wait_until(func() -> bool: return bullet.global_position.x - p.global_position.x <= 7.0 + per_tick, 60)
	input.push(Vector2.UP, 1, 0, InputFrame.DODGE, _aim_right(p))
	await step(1)
	check(p.is_stealthed(), "투명 시작")
	await step(DB.stealth.stealth_ticks - 2)
	check(p.is_stealthed(), "투명 유지 (%d틱)" % DB.stealth.stealth_ticks)
	await step(2)
	check(not p.is_stealthed() and _ev(&"stealth_off") == 1, "시간이 지나면 투명 해제")


## 사격·근접·패링이 섞여도 같은 입력이면 같은 결과
func test_combat_determinism() -> void:
	var results: Array[String] = []
	for run in 2:
		var p := await _start()
		var aim := _aim_right(p)
		_enemy_bullet(p.global_position + Vector2(90, 0), Vector2.LEFT)
		input.push(Vector2(0.3, 0), 20, InputFrame.SHOOT, InputFrame.SHOOT, aim)
		input.push(Vector2.ZERO, 1, 0, InputFrame.MELEE, aim)
		input.push(Vector2(1, 0), 30, 0, 0, aim + Vector2(0, 30))
		input.push(Vector2(0, 1), 1, 0, InputFrame.DODGE, aim)
		input.push(Vector2.ZERO, 40, InputFrame.SHOOT, InputFrame.SHOOT, aim)
		await step(100)
		var d := _dummies()
		results.append("%s ammo=%d d0=%d d1=%d parry=%d" % [p.global_position, p.ammo.current,
			d[0].damage_taken, d[1].damage_taken, _ev(&"parry") + _ev(&"perfect_parry")])
	check(results[0] == results[1], "같은 입력 → 같은 전투 결과 (%s)" % results[0])
