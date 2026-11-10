class_name TestM5
extends TestBase
## M5 자동 테스트: 스킬 5종, 출발(첫 조작) 판정, Tab 스킬 설정(출발 전에만), 재시작 시 스킬 유지,
## 표지판, 6구간 구성, 숨은 테크 문구 금지

const MAP := "res://tests/maps/m3_test.txt"

var _events: Dictionary = {}
var _conns: Array = []


func run_all() -> void:
	print("[M5] 스킬·스킬 설정")
	_conns = [
		[Events.skill_used, func(_id: String) -> void: _count(&"skill")],
		[Events.clock_started, func() -> void: _count(&"clock")],
		[Events.skill_changed, func(_id: String) -> void: _count(&"changed")],
	]
	for c: Array in _conns:
		(c[0] as Signal).connect(c[1])
	test_skill_texts_do_not_reveal_hidden_tech()
	await test_clock_starts_on_first_action()
	await test_blink()
	await test_blink_crosses_pit_not_wall()
	await test_absorb()
	await test_decoy()
	await test_shockwave()
	await test_mark()
	await test_cooldown_and_hud_ratio()
	await test_skill_panel_before_start_only()
	await test_signpost()
	await test_section6_blink_shortcut()
	for c: Array in _conns:
		(c[0] as Signal).disconnect(c[1])
	if level != null:
		level.queue_free()
		level = null


func _count(key: StringName) -> void:
	_events[key] = int(_events.get(key, 0)) + 1


func _ev(key: StringName) -> int:
	return int(_events.get(key, 0))


func _start(skill_id: String) -> Player:
	await new_level(MAP)
	_events.clear()
	level.player.set_skill(DB.skill_by_id(skill_id))
	return level.player


func _use_skill(p: Player, move: Vector2 = Vector2.ZERO, aim: Vector2 = Vector2.INF) -> void:
	var a := aim if aim != Vector2.INF else p.global_position + Vector2(80, 0)
	input.push(move, 1, 0, InputFrame.SKILL, a)
	await step(1)


func test_skill_texts_do_not_reveal_hidden_tech() -> void:
	var forbidden := ["처형", "은신", "돌진 베기", "재패링", "콤보", "연속"]
	var texts: Array[String] = []
	for sd: SkillData in DB.skills:
		texts.append(sd.description)
	for sd: TutorialSectionData in DB.game_config.tutorial.sections:
		texts.append(sd.sign_text)
	texts.append(DB.game_config.tutorial.pre_start_hint)
	var bad: Array[String] = []
	for t in texts:
		for w: String in forbidden:
			if t.contains(w):
				bad.append("%s ← %s" % [t, w])
	check(bad.is_empty(), "스킬 설명·표지판에 숨은 테크 단어 없음 %s" % [bad])
	check(DB.skills.size() == 5, "스킬 5종")
	var rec := DB.skills.filter(func(s: SkillData) -> bool: return s.recommended)
	check(rec.size() == 1 and rec[0].id == "shockwave", "충격파만 추천")


func test_clock_starts_on_first_action() -> void:
	var p := await _start("shockwave")
	input.push(Vector2.ZERO, 10, 0, 0, p.global_position + Vector2(40, 30))
	await step(10)
	check(not Game.clock_running, "마우스(조준)만 움직이면 출발 아님")
	input.push(Vector2.LEFT, 1, 0, 0, p.global_position)
	await step(1)
	check(Game.clock_running and _ev(&"clock") == 1, "첫 이동 입력에 출발")


func test_blink() -> void:
	var p := await _start("blink")
	var d := DB.skill_by_id("blink") as BlinkData
	var start := p.global_position
	await _use_skill(p, Vector2.RIGHT)
	# 순간이동한 틱에 이동 입력만큼 조금 더 움직인다
	check_near(p.global_position.x - start.x, d.distance + DB.player.move_speed / 60.0, 0.01, "블링크: 이동 방향으로 순간이동")
	check(p.is_invulnerable(), "블링크 직후 잠깐 무적 (탄 통과)")
	check(_ev(&"skill") == 1, "스킬 사용 이벤트")
	await step(d.invuln_ticks)
	check(not p.is_invulnerable(), "무적 끝")


func test_blink_crosses_pit_not_wall() -> void:
	await new_tutorial_level()
	_events.clear()
	var p := level.player
	p.set_skill(DB.skill_by_id("blink"))
	# 6구간 구덩이 띠(구간 기준 9~10열) 바로 앞(8열)에서 오른쪽으로
	var base: Vector2i = level.map.section_cells[6]
	p.teleport(LevelMap.cell_center(base + Vector2i(8, 0)))
	await step(1)
	var before := p.global_position
	await _use_skill(p, Vector2.RIGHT)
	var pit_right := LevelMap.cell_center(base + Vector2i(10, 0)).x + 8.0
	check(p.global_position.x > pit_right, "블링크로 구덩이를 건넘 (x %.0f → %.0f)" % [before.x, p.global_position.x])
	# 벽은 못 넘음: 맨 위 벽을 향해
	await step(DB.skill_by_id("blink").cooldown_ticks)
	var top := p.global_position
	await _use_skill(p, Vector2.UP)
	check(p.global_position.y >= 16.0 + DB.player.body_radius - DB.player.body_offset_y - 0.5, "벽은 뚫지 않음 (y=%.1f)" % p.global_position.y)
	check(p.global_position.y < top.y, "벽 앞까지는 감")


func test_absorb() -> void:
	var p := await _start("absorb")
	p.ammo.set_current(0)
	await _use_skill(p)
	for i in 3:
		Projectile.spawn(level.projectiles, Team.ENEMY, p.global_position + Vector2(40 + i * 12, 0), Vector2.LEFT, DB.test_turret.projectile)
	await step(40)
	check(p.ammo.current == 3 * (DB.skill_by_id("absorb") as AbsorbData).ammo_per_bullet, "흡수 장막: 적 탄 3개 → 탄약 3 (%d)" % p.ammo.current)
	check(p.health.current == DB.player.max_hp, "장막 앞 탄에 맞지 않음")
	await step((DB.skill_by_id("absorb") as AbsorbData).duration_ticks)
	var b := Projectile.spawn(level.projectiles, Team.ENEMY, p.global_position + Vector2(30, 0), Vector2.LEFT, DB.test_turret.projectile)
	await step(30)
	check(p.health.current < DB.player.max_hp, "지속 시간이 끝나면 다시 맞음")


func test_decoy() -> void:
	var p := await _start("decoy")
	var s := spawn_enemy("shooter", p.global_position + Vector2(100, 0)) as Shooter
	await step(3)
	check(s.sees_player and s.target_pos.distance_to(p.global_position) < 1.0, "원거리형이 플레이어를 노림")
	await _use_skill(p)
	var decoy_pos := p.global_position
	input.push(Vector2.DOWN, 30, 0, 0, p.global_position)
	await step(30)
	check(s.target_pos.distance_to(decoy_pos) < 1.0, "분신이 보이면 분신을 노림")
	check(p.global_position.distance_to(decoy_pos) > 30.0, "플레이어는 이미 다른 곳")
	await step((DB.skill_by_id("decoy") as DecoyData).duration_ticks)
	check(get_tree().get_nodes_in_group(Decoy.GROUP).is_empty(), "시간이 지나면 분신 사라짐")
	await step(2)
	check(s.target_pos.distance_to(p.global_position) < 1.0, "분신이 사라지면 다시 플레이어를 노림")


func test_shockwave() -> void:
	var p := await _start("shockwave")
	var d := DB.skill_by_id("shockwave") as ShockwaveData
	var near_id := Projectile.spawn(level.projectiles, Team.ENEMY, p.global_position + Vector2(30, 0), Vector2.UP, DB.test_turret.projectile).get_instance_id()
	var far_id := Projectile.spawn(level.projectiles, Team.ENEMY, p.global_position + Vector2(d.radius + 40, 0), Vector2.UP, DB.test_turret.projectile).get_instance_id()
	var e := spawn_enemy("charger", p.global_position + Vector2(0, 40))
	await step(1)
	var e_before := e.global_position
	await _use_skill(p)
	var near := instance_from_id(near_id) as Projectile
	var far := instance_from_id(far_id) as Projectile
	check((near == null or not near.alive) and far != null and far.alive, "충격파: 범위 안 적 탄만 없앰")
	await step(5)
	check(e.global_position.y > e_before.y + 5.0, "범위 안 적을 밀쳐냄")


func test_mark() -> void:
	var p := await _start("mark")
	var a := spawn_enemy("charger", p.global_position + Vector2(80, -20))
	var b := spawn_enemy("charger", p.global_position + Vector2(80, 30))
	await step(1)
	await _use_skill(p, Vector2.ZERO, b.global_position)
	check(b.mark_left > 0 and a.mark_left == 0, "조준점에 가장 가까운 적에게 표식")
	var hp := b.hp
	b.hurtbox.receive_hit(HitInfo.make(1, HitInfo.Kind.BULLET, Team.PLAYER, Vector2.RIGHT, null))
	var expected := ceili(1 * (DB.skill_by_id("mark") as MarkData).damage_mult)
	check(hp - b.hp == expected, "표식된 적은 데미지 증가 (1 → %d)" % (hp - b.hp))
	# 대상이 없으면 발동 안 함
	var p2 := await _start("mark")
	await _use_skill(p2)
	check(_ev(&"skill") == 0 and p2.skill.can_use(), "대상이 없으면 발동하지 않고 쿨타임도 안 씀")


func test_cooldown_and_hud_ratio() -> void:
	var p := await _start("shockwave")
	await _use_skill(p)
	check(not p.skill.can_use() and p.skill.ready_ratio() < 0.1, "쓰면 쿨타임 시작")
	await _use_skill(p)
	check(_ev(&"skill") == 1, "쿨타임 중엔 다시 못 씀")
	await step(p.skill.data.cooldown_ticks)
	check(p.skill.can_use() and is_equal_approx(p.skill.ready_ratio(), 1.0), "쿨타임 끝나면 다시 사용 가능")


func _tab() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = &"skill_menu"
	ev.pressed = true
	return ev


func test_skill_panel_before_start_only() -> void:
	if level != null:
		level.queue_free()
		level = null
	input = ScriptedInputSource.new()
	PlayerInput.source = input
	var setup := RunSetup.from_config(DB.game_config)
	var run := RunController.new(setup)
	add_child(run)
	var panel := SkillPanel.new(run)
	add_child(panel)
	await step(1)
	_events.clear()
	check(run.level.player.skill.data.id == DB.game_config.default_skill_id, "기본 스킬(%s)로 시작" % DB.game_config.default_skill_id)
	panel._unhandled_input(_tab())
	check(panel.is_open and get_tree().paused, "출발 전 Tab → 스킬 설정 창 열림, 게임 멈춤")
	var t := Game.tick
	await step(5)
	check(Game.tick == t, "창이 열려 있는 동안 틱 멈춤")
	var blink_index := DB.skills.find(DB.skill_by_id("blink"))
	panel._select(blink_index)
	panel._unhandled_input(_tab())
	check(not panel.is_open and not get_tree().paused, "Tab 으로 확정하고 닫힘")
	check(run.level.player.skill.data.id == "blink" and _ev(&"changed") == 1, "스킬이 블링크로 바뀜")
	check(not Game.clock_running, "스킬을 골라도 출발하지 않음")
	# 출발 후엔 못 엶
	cross_start_line(run.level.player)
	await step(2)
	panel._unhandled_input(_tab())
	check(Game.clock_running and not panel.is_open, "출발한 뒤에는 Tab 으로 못 엶")
	# 재시작해도 스킬 유지, 다시 바꿀 수 있음
	run.restart()
	await step(1)
	check(run.level.player.skill.data.id == "blink", "재시작해도 고른 스킬 유지")
	panel._unhandled_input(_tab())
	check(panel.is_open, "재시작 후 출발 전엔 다시 열 수 있음")
	var ev := InputEventAction.new()
	ev.action = &"pause"
	ev.pressed = true
	panel._unhandled_input(ev)
	check(not panel.is_open and run.level.player.skill.data.id == "blink", "Esc 는 취소 (그대로 유지)")
	panel.queue_free()
	run.queue_free()
	await step(1)


func test_signpost() -> void:
	await new_tutorial_level()
	var sign: Signpost = null
	for n in level.props.get_children():
		if n is Signpost:
			sign = n
	check(sign != null and sign.text.contains("Tab"), "1구간 출발 지점 옆 표지판에 스킬 설정 안내")
	level.player.teleport(sign.global_position + Vector2(200, 0))
	await step(2)
	check(not sign.is_showing(), "멀면 글상자 안 보임")
	level.player.teleport(sign.global_position + Vector2(10, 10))
	await step(2)
	check(sign.is_showing(), "가까이 가면 글상자 표시 (게임은 계속)")
	check(not get_tree().paused, "표지판은 게임을 멈추지 않음")


func test_section6_blink_shortcut() -> void:
	await new_tutorial_level()
	var enemies: Array = level.director.contents(6)["enemies"]
	var kinds := {}
	for e: Variant in enemies:
		kinds[(e as Enemy).data.sheet] = true
	check(kinds.size() == 3, "6구간에 적 3종이 섞여 있음 (스킬마다 이득)")
	check(level.director.section_of(LevelMap.cell_center(level.map.section_cells[6] + Vector2i(10, 0)).x) == 6, "구덩이 띠는 6구간 안")
