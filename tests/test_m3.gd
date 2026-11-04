class_name TestM3
extends TestBase
## M3 자동 테스트: 체력·피격 무적·사망, 재시작(사망·R 홀드), 일시정지, 적 3종, 투명 시 놓침
## 테스트 맵: 플레이어 (40,40), 가운데 세로 벽 x=13칸(208~224px) 2~3행

const MAP := "res://tests/maps/m3_test.txt"

var _events: Dictionary = {}
var _conns: Array = []


func run_all() -> void:
	print("[M3] 적·체력·사망·재시작")
	_conns = [
		[Events.player_died, func() -> void: _count(&"died")],
		[Events.enemy_died, func(_e: Node2D) -> void: _count(&"enemy_died")],
		[Events.run_started, func() -> void: _count(&"run_started")],
	]
	for c: Array in _conns:
		(c[0] as Signal).connect(c[1])
	await test_hp_and_hurt_invuln()
	await test_death()
	await test_restart_on_death()
	await test_restart_hold()
	await test_pause_stops_ticks()
	await test_charger()
	await test_charger_stops_at_wall()
	await test_enemy_loses_stealthed_player()
	await test_sight_blocked_by_wall()
	await test_shooter_fires_and_dies_to_parry()
	await test_shooter_holds_fire_when_stealthed()
	await test_spreader_volley()
	await test_shooting_kills_and_melee_recovers()
	await test_enemy_determinism()
	for c: Array in _conns:
		(c[0] as Signal).disconnect(c[1])
	if level != null:
		level.queue_free()
		level = null


func _count(key: StringName) -> void:
	_events[key] = int(_events.get(key, 0)) + 1


func _ev(key: StringName) -> int:
	return int(_events.get(key, 0))


func _start() -> Player:
	await new_level(MAP)
	_events.clear()
	return level.player


func _enemy_bullet(from: Vector2, dir: Vector2) -> Projectile:
	return Projectile.spawn(level.projectiles, Team.ENEMY, from, dir, DB.test_turret.projectile)


func _enemy_bullets() -> int:
	return get_tree().get_nodes_in_group(Projectile.GROUP_ENEMY).size()


## 레벨 대신 런 관리자째로 띄운다 (재시작 테스트용)
func _start_run() -> RunController:
	if level != null:
		level.queue_free()
		level = null
	input = ScriptedInputSource.new()
	PlayerInput.source = input
	var setup := RunSetup.new()
	setup.map_path = MAP
	setup.seed_value = DB.game_config.run_seed
	var run := RunController.new(setup)
	add_child(run)
	await step(1)
	_events.clear()
	return run


func test_hp_and_hurt_invuln() -> void:
	var p := await _start()
	var max_hp := DB.player.max_hp
	_enemy_bullet(p.global_position + Vector2(20, 0), Vector2.LEFT)
	await wait_until(func() -> bool: return p.health.current < max_hp, 30)
	check(p.health.current == max_hp - 1, "적 탄에 맞으면 체력 -1 (%d/%d)" % [p.health.current, max_hp])
	check(p.is_invulnerable(), "맞은 직후 무적")
	_enemy_bullet(p.global_position + Vector2(12, 0), Vector2.LEFT)
	await step(10)
	check(p.health.current == max_hp - 1, "무적 중엔 추가 피해 없음")
	await step(DB.player.hurt_invuln_ticks)
	_enemy_bullet(p.global_position + Vector2(12, 0), Vector2.LEFT)
	await step(10)
	check(p.health.current == max_hp - 2, "무적이 끝나면 다시 맞음")


func test_death() -> void:
	var p := await _start()
	p.health.current = 1
	_enemy_bullet(p.global_position + Vector2(12, 0), Vector2.LEFT)
	await step(10)
	check(p.is_dead() and _ev(&"died") == 1, "체력 0 → 사망")
	var pos := p.global_position
	input.push(Vector2.RIGHT, 10, InputFrame.SHOOT, InputFrame.SHOOT, pos + Vector2(50, 0))
	await step(10)
	check(p.global_position == pos and p.ammo.current == DB.gun.magazine_size, "사망 후엔 움직이거나 쏘지 못함")


func test_restart_on_death() -> void:
	var run := await _start_run()
	var old_level := run.level
	var p := run.level.player
	p.health.current = 1
	Projectile.spawn(run.level.projectiles, Team.ENEMY, p.global_position + Vector2(12, 0), Vector2.LEFT, DB.test_turret.projectile)
	await step(10)
	check(_ev(&"died") == 1, "런: 사망")
	await step(DB.game_config.death_restart_delay_ticks + 2)
	check(run.level != old_level and _ev(&"run_started") == 1, "사망 후 자동으로 처음부터 재시작")
	check(run.level.player.health.current == DB.player.max_hp, "재시작하면 체력 가득")
	check(Game.tick < DB.game_config.death_restart_delay_ticks, "재시작하면 틱 초기화 (tick=%d)" % Game.tick)
	run.queue_free()
	await step(1)


func test_restart_hold() -> void:
	var run := await _start_run()
	var first := run.level
	var hold := DB.game_config.restart_hold_ticks
	# 짧게 누르면 재시작 안 됨
	Input.action_press(&"restart")
	await step(hold / 2)
	Input.action_release(&"restart")
	await step(3)
	check(run.level == first, "R 짧게 누르면 재시작 안 함")
	# 길게 누르면 재시작
	Input.action_press(&"restart")
	await step(hold + 2)
	check(run.level != first, "R 을 %d틱 누르면 재시작" % hold)
	var second := run.level
	await step(hold + 5)
	check(run.level == second, "계속 누르고 있어도 연속 재시작 안 함")
	Input.action_release(&"restart")
	await step(2)
	run.queue_free()
	await step(1)


func test_pause_stops_ticks() -> void:
	var run := await _start_run()
	var ev := InputEventAction.new()
	ev.action = &"pause"
	ev.pressed = true
	run._unhandled_input(ev)
	var t := Game.tick
	await step(10)
	check(get_tree().paused and Game.tick == t, "일시정지 중엔 게임 틱이 멈춤")
	run._unhandled_input(ev)
	await step(5)
	check(not get_tree().paused and Game.tick > t, "다시 Esc 로 재개")
	run.queue_free()
	await step(1)


func test_charger() -> void:
	var p := await _start()
	var c := spawn_enemy("charger", p.global_position + Vector2(110, 0)) as Charger
	var saw_windup := await wait_until(func() -> bool: return c.state == Charger.State.WINDUP, 120)
	check(saw_windup, "돌진형: 다가오다 돌진 준비(예고)")
	var charged := await wait_until(func() -> bool: return c.state == Charger.State.CHARGE, 60)
	check(charged, "돌진형: 예고 후 돌진")
	await wait_until(func() -> bool: return p.health.current < DB.player.max_hp, 60)
	check(p.health.current < DB.player.max_hp, "돌진에 맞으면 피해")


func test_charger_stops_at_wall() -> void:
	var p := await _start()
	# 플레이어가 벽 너머 아래쪽에 있을 때, 돌진형을 벽 왼쪽에 두고 오른쪽으로 돌진시킨다
	p.teleport(LevelMap.cell_center(Vector2i(16, 3)))
	var c := spawn_enemy("charger", LevelMap.cell_center(Vector2i(10, 4)) + Vector2(0, -8)) as Charger
	await step(1)
	c.state = Charger.State.CHARGE
	c._charge_dir = Vector2.UP
	c._timer = 999
	var stopped := await wait_until(func() -> bool: return c.state == Charger.State.RECOVER, 60)
	check(stopped, "돌진 중 벽에 부딪히면 멈춤")


func test_enemy_loses_stealthed_player() -> void:
	var p := await _start()
	var c := spawn_enemy("charger", p.global_position + Vector2(130, 30)) as Charger
	await step(3)
	check(c.has_target and c.sees_player, "적이 플레이어를 봄")
	var seen := c.target_pos
	p.stealth_ticks_left = 300
	input.push(Vector2.DOWN, 30, 0, 0, p.global_position)
	await step(30)
	check(not c.sees_player, "투명이면 못 봄")
	check(c.target_pos == seen, "마지막으로 본 위치를 기억")
	await step(150)
	check(c.global_position.distance_to(seen) <= c.data.arrive_distance + 1.0
		or c.global_position.distance_to(seen) < c.global_position.distance_to(p.global_position),
		"마지막으로 본 위치로 감 (현재 위치를 쫓지 않음)")
	p.stealth_ticks_left = 0


func test_sight_blocked_by_wall() -> void:
	var p := await _start()
	p.teleport(LevelMap.cell_center(Vector2i(10, 2)))
	var c := spawn_enemy("charger", LevelMap.cell_center(Vector2i(16, 2)))
	await step(20)
	check(not c.has_target, "벽에 가려 있으면 못 알아챔")


func test_shooter_fires_and_dies_to_parry() -> void:
	var p := await _start()
	var s := spawn_enemy("shooter", p.global_position + Vector2(90, 0)) as Shooter
	var sd := s.data as ShooterData
	var fired := await wait_until(func() -> bool: return _enemy_bullets() > 0, sd.first_shot_delay_ticks + 10)
	check(fired, "원거리형: 플레이어를 보면 탄 발사")
	var bullet := get_tree().get_nodes_in_group(Projectile.GROUP_ENEMY)[0] as Projectile
	check(bullet.velocity.normalized().dot((p.global_position - bullet.global_position).normalized()) > 0.95, "플레이어를 향해 쏨")
	# 완벽 패링으로 되받아쳐서 처치
	var per_tick := bullet.velocity.length() / float(Game.config.tick_rate)
	var trigger := DB.melee.offset + DB.melee.radius + bullet.radius + per_tick * 2
	var bid := bullet.get_instance_id()
	await wait_until(func() -> bool:
		var b := instance_from_id(bid) as Projectile
		return b == null or b.global_position.distance_to(p.global_position) <= trigger, 120)
	input.push(Vector2.ZERO, 1, 0, InputFrame.MELEE, s.global_position)
	await wait_until(func() -> bool: return _ev(&"enemy_died") > 0, 90)
	check(_ev(&"enemy_died") == 1 and not is_instance_valid(s), "완벽 반사탄으로 원거리형 처치")


func test_shooter_holds_fire_when_stealthed() -> void:
	var p := await _start()
	var s := spawn_enemy("shooter", p.global_position + Vector2(90, 0)) as Shooter
	await step(3)
	p.stealth_ticks_left = 400
	await step((s.data as ShooterData).fire_interval_ticks * 2)
	check(_enemy_bullets() == 0, "투명이면 원거리형이 쏘지 않음")
	p.stealth_ticks_left = 0


func test_spreader_volley() -> void:
	var p := await _start()
	var b := spawn_enemy("spreader", p.global_position + Vector2(110, 0)) as Spreader
	var d := b.data as SpreaderData
	await wait_until(func() -> bool: return _enemy_bullets() > 0, d.first_shot_delay_ticks + 10)
	check(_enemy_bullets() == d.bullets_per_volley, "탄막형: 한 번에 %d발 원형 발사" % d.bullets_per_volley)
	var first_angle := b._angle_deg
	await wait_until(func() -> bool: return b._angle_deg != first_angle, d.fire_interval_ticks + 5)
	check_near(fposmod(b._angle_deg - first_angle, 360.0), d.rotation_step_deg, 0.01, "발사마다 회전 (나선 탄막)")


func test_shooting_kills_and_melee_recovers() -> void:
	var p := await _start()
	var c := spawn_enemy("charger", p.global_position + Vector2(60, 0))
	c.has_target = false
	var hp := c.data.max_hp
	# 적이 움직이지 않게 시야 밖처럼 만들기 어려우니 바로 연사
	input.push(Vector2.ZERO, DB.gun.fire_interval_ticks * (hp + 2), InputFrame.SHOOT, InputFrame.SHOOT, c.global_position)
	var dead := await wait_until(func() -> bool: return _ev(&"enemy_died") > 0, DB.gun.fire_interval_ticks * (hp + 4))
	check(dead, "사격으로 돌진형 처치 (체력 %d)" % hp)
	# 근접 명중 → 탄약 회복
	var p2 := await _start()
	var c2 := spawn_enemy("shooter", p2.global_position + Vector2(16, 0))
	p2.ammo.set_current(0)
	input.push(Vector2.ZERO, 1, 0, InputFrame.MELEE, c2.global_position)
	await step(2)
	check(p2.ammo.current == DB.melee.ammo_on_hit, "적을 근접으로 맞히면 탄약 회복")


func test_enemy_determinism() -> void:
	var results: Array[String] = []
	for run in 2:
		var p := await _start()
		spawn_enemy("charger", p.global_position + Vector2(120, 10))
		spawn_enemy("shooter", p.global_position + Vector2(150, -10))
		spawn_enemy("spreader", p.global_position + Vector2(200, 20))
		var aim := p.global_position + Vector2(100, 0)
		input.push(Vector2(0, 1), 30, InputFrame.SHOOT, InputFrame.SHOOT, aim)
		input.push(Vector2(1, -1).normalized(), 1, 0, InputFrame.DODGE, aim)
		input.push(Vector2(0, -1), 40, 0, 0, aim)
		input.push(Vector2.ZERO, 1, 0, InputFrame.MELEE, aim)
		input.push(Vector2(-1, 0), 80, InputFrame.SHOOT, 0, aim)
		await step(200)
		var parts: Array[String] = ["%s hp=%d ammo=%d" % [p.global_position, p.health.current, p.ammo.current]]
		for e in get_tree().get_nodes_in_group(Enemy.GROUP):
			parts.append("%s:%s:%d" % [e.get_class(), (e as Enemy).global_position, (e as Enemy).hp])
		parts.append("bullets=%d" % _enemy_bullets())
		results.append(" ".join(parts))
	check(results[0] == results[1], "적이 있어도 같은 입력 → 같은 결과")
	if results[0] != results[1]:
		print("    1: ", results[0])
		print("    2: ", results[1])
