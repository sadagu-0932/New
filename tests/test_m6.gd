class_name TestM6
extends TestBase
## M6 자동 테스트: 탄막 골렘 1페이즈(깨어남·패턴·코어·그로기), 격파 → 타이머 정지 → 2페이즈 시작 컷씬,
## 컷씬 건너뛰기(두 번째부터), 본편 모드 2페이즈, 실제 패링으로 코어 명중

var _events: Dictionary = {}
var _conns: Array = []


func run_all() -> void:
	print("[M6] 탄막 골렘·컷씬")
	SaveData.use_file("user://test_save.json", true)
	_conns = [
		[Events.boss_started, func(_b: Node2D) -> void: _count(&"boss_started")],
		[Events.boss_groggy, func() -> void: _count(&"groggy")],
		[Events.boss_defeated, func(_b: Node2D) -> void: _count(&"defeated")],
		[Events.demo_finished, func() -> void: _count(&"demo_finished")],
		[Events.player_died, func() -> void: _count(&"player_died")],
		[Events.run_started, func() -> void: _count(&"run_started")],
	]
	for c: Array in _conns:
		(c[0] as Signal).connect(c[1])
	await test_wakes_on_section7()
	await test_body_chip_damage()
	await test_reflect_hits_core()
	await test_groggy()
	await test_groggy_chain_window()
	await test_patterns_deterministic()
	await test_real_parry_into_core()
	await test_defeat_and_cutscene()
	await test_cutscene_skip_second_time()
	await test_phase2_when_not_demo()
	await test_run_restarts_after_demo()
	for c: Array in _conns:
		(c[0] as Signal).disconnect(c[1])
	if level != null:
		level.queue_free()
		level = null
	SaveData.use_file("user://test_save.json", true)
	SaveData.use_file("user://save.json")


func _count(key: StringName) -> void:
	_events[key] = int(_events.get(key, 0)) + 1


func _ev(key: StringName) -> int:
	return int(_events.get(key, 0))


func _golem() -> Golem:
	for e: Variant in level.director.contents(7)["enemies"]:
		if e is Golem:
			return e
	return null


func _gdata() -> GolemData:
	return DB.enemies["golem"] as GolemData


## 튜토리얼을 띄우고 7구간에 들어가 골렘을 깨운다 (wait_intro 면 공격 시작까지)
func _arena(wait_intro: bool = true) -> Golem:
	await new_tutorial_level()
	_events.clear()
	var p := level.player
	Debug.god_mode = true
	p.teleport(LevelMap.cell_center(level.map.section_cells[7] + Vector2i(2, 0)))
	await step(2)
	if wait_intro:
		await step(_gdata().intro_ticks + 1)
	return _golem()


func _hit(g: Golem, kind: HitInfo.Kind, damage: int, perfect: bool = false) -> void:
	var h := HitInfo.make(damage, kind, Team.PLAYER, Vector2.RIGHT, null)
	h.perfect = perfect
	g.hurtbox.receive_hit(h)


func _enemy_bullets() -> int:
	return get_tree().get_nodes_in_group(Projectile.GROUP_ENEMY).size()


func test_wakes_on_section7() -> void:
	await new_tutorial_level()
	_events.clear()
	var g := _golem()
	check(g != null and g.mode == Golem.Mode.DORMANT, "골렘이 7구간에 잠들어 있음")
	level.player.teleport(LevelMap.cell_center(level.map.section_cells[7] + Vector2i(2, 0)))
	await step(2)
	check(g.mode == Golem.Mode.INTRO and _ev(&"boss_started") == 1, "7구간 입장 → 깨어남, 보스 체력바 표시 이벤트")
	await step(_gdata().intro_ticks + _gdata().rest_ticks + 40)
	check(g.mode == Golem.Mode.FIGHT and _enemy_bullets() > 0, "등장 연출 후 탄막 시작")


func test_body_chip_damage() -> void:
	var g := await _arena()
	var hp := g.hp
	for i in _gdata().body_hits_per_damage - 1:
		_hit(g, HitInfo.Kind.BULLET, 1)
	check(g.hp == hp, "몸통은 일반 탄 %d번엔 피해 없음" % (_gdata().body_hits_per_damage - 1))
	_hit(g, HitInfo.Kind.MELEE, 2)
	check(g.hp == hp - 1, "%d번째에 겨우 1 (일반 공격은 거의 안 들어감)" % _gdata().body_hits_per_damage)


func test_reflect_hits_core() -> void:
	var g := await _arena()
	var hp := g.hp
	_hit(g, HitInfo.Kind.REFLECT, DB.parry.reflect_damage)
	check(hp - g.hp == ceili(DB.parry.reflect_damage * _gdata().core_damage_mult), "반사탄은 코어에 제대로 (−%d)" % (hp - g.hp))


func test_groggy() -> void:
	var g := await _arena()
	var perfect_dmg := roundi(DB.parry.reflect_damage * DB.parry.perfect_damage_mult)
	for i in _gdata().groggy_perfect_hits:
		check(not g.is_groggy(), "그로기 전 (%d/%d)" % [i, _gdata().groggy_perfect_hits])
		_hit(g, HitInfo.Kind.REFLECT, perfect_dmg, true)
		await step(10)
	check(g.is_groggy() and _ev(&"groggy") == 1, "완벽 반사탄 %d연속 → 그로기" % _gdata().groggy_perfect_hits)
	for n in get_tree().get_nodes_in_group(Projectile.GROUP_ENEMY):
		(n as Projectile).destroy(false)
	await step(30)
	check(_enemy_bullets() == 0, "그로기 중엔 공격 안 함")
	var hp := g.hp
	_hit(g, HitInfo.Kind.BULLET, 1)
	check(hp - g.hp == ceili(1 * _gdata().groggy_damage_mult), "그로기 중엔 일반 탄도 크게 (−%d)" % (hp - g.hp))
	await step(_gdata().groggy_ticks)
	check(g.mode == Golem.Mode.FIGHT, "그로기가 끝나면 다시 공격")


func test_groggy_chain_window() -> void:
	var g := await _arena()
	var perfect_dmg := roundi(DB.parry.reflect_damage * DB.parry.perfect_damage_mult)
	for i in _gdata().groggy_perfect_hits:
		_hit(g, HitInfo.Kind.REFLECT, perfect_dmg, true)
		await step(_gdata().groggy_chain_window_ticks + 5)
	check(not g.is_groggy(), "간격이 너무 길면 연속으로 치지 않음")
	_hit(g, HitInfo.Kind.REFLECT, perfect_dmg, true)
	_hit(g, HitInfo.Kind.REFLECT, DB.parry.reflect_damage, false)
	_hit(g, HitInfo.Kind.REFLECT, perfect_dmg, true)
	check(not g.is_groggy(), "중간에 일반 반사가 끼면 연속이 끊김")


func test_patterns_deterministic() -> void:
	var histories: Array[String] = []
	for run in 2:
		var g := await _arena()
		await step(1500)
		var h := (g.phase as GolemPhase1).history
		histories.append(str(h))
		var repeated := false
		for i in range(1, h.size()):
			if h[i] == h[i - 1]:
				repeated = true
		check(h.size() >= 4 and not repeated, "패턴 %d개, 같은 패턴 연달아 안 씀 %s" % [h.size(), h])
		var kinds := {}
		for p in h:
			kinds[p] = true
		check(kinds.size() == 3, "패턴 3종 모두 나옴")
	check(histories[0] == histories[1], "고정 시드: 매 판 같은 패턴 순서 %s" % histories[0])


## 골렘 방향에서 날아오는 탄을 실제로 완벽 패링해서 코어에 맞힌다
func test_real_parry_into_core() -> void:
	var g := await _arena()
	var p := level.player
	for n in get_tree().get_nodes_in_group(Projectile.GROUP_ENEMY):
		(n as Projectile).destroy(false)
	g.mode = Golem.Mode.GROGGY  # 골렘 탄막이 끼어들지 않게 잠시 멈춤
	g._timer = 9999
	var dir := (p.global_position - g.global_position).normalized()
	var b := Projectile.spawn(level.projectiles, Team.ENEMY, p.global_position - dir * 50.0, dir, _gdata().projectile)
	var bid := b.get_instance_id()
	var per_tick := b.velocity.length() / float(Game.config.tick_rate)
	var trigger := DB.melee.offset + DB.melee.radius + b.radius + per_tick * 2
	await wait_until(func() -> bool:
		var x := instance_from_id(bid) as Projectile
		return x == null or x.global_position.distance_to(p.global_position) <= trigger, 120)
	g.mode = Golem.Mode.FIGHT
	g.enter_phase(GolemPhase1.new(g))
	(g.phase as GolemPhase1)._rest = 9999
	var hp := g.hp
	input.push(Vector2.ZERO, 1, 0, InputFrame.MELEE, g.global_position)
	await wait_until(func() -> bool: return g.hp < hp, 240)
	var perfect_dmg := roundi(DB.parry.reflect_damage * DB.parry.perfect_damage_mult)
	check(hp - g.hp == perfect_dmg, "실제 완벽 패링 → 반사탄이 코어 명중 (−%d)" % (hp - g.hp))


func test_defeat_and_cutscene() -> void:
	SaveData.use_file("user://test_save.json", true)
	var g := await _arena()
	Debug.god_mode = false
	var p := level.player
	# 출발(타이머 시작)
	input.push(Vector2.LEFT, 1, 0, 0, g.global_position)
	await step(5)
	g.hp = 1
	_hit(g, HitInfo.Kind.REFLECT, DB.parry.reflect_damage)
	check(_ev(&"defeated") == 1 and g.defeated, "체력 0 → 1페이즈 격파")
	check(Game.clock_stopped and Game.elapsed_ticks() > 0, "타이머 정지 (%d틱)" % Game.elapsed_ticks())
	var t := Game.elapsed_ticks()
	await step(2)
	check(_enemy_bullets() == 0, "남은 적 탄 정리")
	check(p.cutscene_lock and p.is_invulnerable(), "컷씬 중 조작 불가·무적")
	var cut: GolemCutscene = null
	for n in level.props.get_children():
		if n is GolemCutscene:
			cut = n
	check(cut != null and cut.step == GolemCutscene.Step.AWAKEN and not cut.skippable, "각성 연출 시작, 첫 회는 건너뛰기 불가")
	# 첫 회: E 를 눌러도 건너뛰지 않음
	Input.action_press(&"interact")
	await step(3)
	Input.action_release(&"interact")
	check(cut.step == GolemCutscene.Step.AWAKEN, "첫 회는 E 로 건너뛸 수 없음")
	var d := _gdata()
	await wait_until(func() -> bool: return cut.step == GolemCutscene.Step.SPECIAL, d.cut_awaken_ticks + 5)
	check(cut.step == GolemCutscene.Step.SPECIAL, "필살기")
	await wait_until(func() -> bool: return cut.step == GolemCutscene.Step.COLLAPSE, d.cut_special_ticks + 5)
	check(p.is_dead() and _ev(&"player_died") == 0, "주인공 쓰러짐 (사망·재시작 처리는 안 함)")
	await wait_until(func() -> bool: return cut.step == GolemCutscene.Step.TEXT, d.cut_collapse_ticks + d.cut_fade_ticks + 5)
	check(cut._text.visible and cut._black.color.a >= 0.99, "암전 → TO BE CONTINUED")
	await wait_until(func() -> bool: return _ev(&"demo_finished") > 0, d.cut_text_ticks + 5)
	check(_ev(&"demo_finished") == 1, "컷씬 끝 → 데모 종료(기록 화면으로) 이벤트")
	check(Game.elapsed_ticks() == t, "컷씬 시간은 기록에 안 들어감")
	check(bool(SaveData.get_value(GolemCutscene.SAVE_KEY, false)), "컷씬 시청 기록 저장")


func test_cutscene_skip_second_time() -> void:
	# 앞 테스트에서 시청 기록이 저장됨
	var g := await _arena()
	g.hp = 1
	_hit(g, HitInfo.Kind.REFLECT, DB.parry.reflect_damage)
	await step(2)
	var cut: GolemCutscene = null
	for n in level.props.get_children():
		if n is GolemCutscene:
			cut = n
	check(cut.skippable and cut._skip_label.visible, "두 번째부터 건너뛰기 가능 (안내 표시)")
	Input.action_press(&"interact")
	await step(3)
	Input.action_release(&"interact")
	check(_ev(&"demo_finished") == 1, "E 로 바로 건너뜀")


func test_phase2_when_not_demo() -> void:
	DB.game_config.demo_mode = false
	var g := await _arena()
	g.hp = 1
	_hit(g, HitInfo.Kind.REFLECT, DB.parry.reflect_damage)
	var d := _gdata()
	await step(d.cut_awaken_ticks + d.cut_special_ticks + 5)
	check(g.phase is GolemPhase2 and g.phase.number() == 2, "본편 모드: 컷씬 뒤 2페이즈 전투")
	check(not level.player.cutscene_lock and not level.player.is_dead(), "본편 모드: 주인공은 쓰러지지 않고 계속")
	check(g.hp == d.max_hp and _ev(&"demo_finished") == 0, "2페이즈 체력 회복, 데모 종료 없음")
	DB.game_config.demo_mode = true


func test_run_restarts_after_demo() -> void:
	if level != null:
		level.queue_free()
		level = null
	input = ScriptedInputSource.new()
	PlayerInput.source = input
	var run := RunController.new(RunSetup.from_config(DB.game_config))
	add_child(run)
	await step(1)
	level = run.level
	_events.clear()
	var first := run.level
	level.player.teleport(LevelMap.cell_center(level.map.section_cells[7] + Vector2i(2, 0)))
	await step(2)
	var g := _golem()
	g.hp = 1
	_hit(g, HitInfo.Kind.REFLECT, DB.parry.reflect_damage)
	await step(3)
	Input.action_press(&"interact")
	await step(3)
	Input.action_release(&"interact")
	await step(2)
	check(run.level != first and _ev(&"run_started") == 1, "데모 종료 후 처음부터 다시 (TODO M7: 기록 화면)")
	level = null
	run.queue_free()
	await step(1)
