class_name TestM8
extends TestBase
## M8 자동 테스트: 숨은 테크 4종 (은신 처형 / 반사탄 재패링 / 돌진 베기 / 연속 퍼펙트 콤보)

const MAP := "res://tests/maps/m3_test.txt"
const DUMMY_MAP := "res://tests/maps/m2_test.txt"

var _events: Dictionary = {}
var _conns: Array = []


func run_all() -> void:
	print("[M8] 숨은 테크")
	_conns = [
		[Events.executed, func() -> void: _count(&"executed")],
		[Events.reparried, func(_c: int) -> void: _count(&"reparried")],
		[Events.dash_slashed, func() -> void: _count(&"dash")],
		[Events.combo_changed, func(s: int) -> void: _events[&"stage"] = s],
	]
	for c: Array in _conns:
		(c[0] as Signal).connect(c[1])
	await test_execute()
	await test_execute_needs_stealth()
	await test_execute_golem_core()
	await test_reparry_chain()
	await test_dash_slash()
	await test_combo()
	test_no_hidden_tech_text_anywhere()
	for c: Array in _conns:
		(c[0] as Signal).disconnect(c[1])
	if level != null:
		level.queue_free()
		level = null


func _count(key: StringName) -> void:
	_events[key] = int(_events.get(key, 0)) + 1


func _ev(key: StringName) -> int:
	return int(_events.get(key, 0))


func _start(map := MAP) -> Player:
	await new_level(map)
	_events.clear()
	return level.player


func test_execute() -> void:
	var p := await _start()
	var e := spawn_enemy("shooter", p.global_position + Vector2(14, 0))
	await step(1)
	p.ammo.set_current(0)
	p.stealth_ticks_left = 60
	input.push(Vector2.ZERO, 1, 0, InputFrame.INTERACT, e.global_position)
	await step(2)
	check(_ev(&"executed") == 1 and not is_instance_valid(e), "투명 + 붙어서 E → 은신 처형 (처치)")
	check(p.ammo.current == DB.advanced.execute_ammo, "탄약 대량 흡수 (+%d)" % p.ammo.current)
	check(not p.is_stealthed(), "처형하면 투명 풀림")


func test_execute_needs_stealth() -> void:
	var p := await _start()
	var e := spawn_enemy("shooter", p.global_position + Vector2(14, 0))
	await step(1)
	var hp := e.hp
	input.push(Vector2.ZERO, 1, 0, InputFrame.INTERACT, e.global_position)
	await step(2)
	check(_ev(&"executed") == 0 and e.hp == hp, "투명이 아니면 처형 안 됨")
	p.stealth_ticks_left = 60
	var far := spawn_enemy("shooter", p.global_position + Vector2(0, 60))
	e.queue_free()
	await step(1)
	input.push(Vector2.ZERO, 1, 0, InputFrame.INTERACT, far.global_position)
	await step(2)
	check(_ev(&"executed") == 0, "멀리 있으면 처형 안 됨")


func test_execute_golem_core() -> void:
	await new_tutorial_level()
	_events.clear()
	var p := level.player
	Debug.god_mode = true
	p.teleport(LevelMap.cell_center(level.map.section_cells[7] + Vector2i(2, 0)))
	await step(DB.enemies["golem"].intro_ticks + 4)
	var g: Golem = null
	for e: Variant in level.director.contents(7)["enemies"]:
		if e is Golem:
			g = e
	p.teleport(g.global_position + Vector2(-g.data.body_radius - 10, 0))
	p.stealth_ticks_left = 60
	var hp := g.hp
	input.push(Vector2.ZERO, 1, 0, InputFrame.INTERACT, g.global_position)
	await step(2)
	check(hp - g.hp == DB.advanced.execute_damage, "골렘에게 처형 → 코어 직격 (−%d)" % (hp - g.hp))
	Debug.god_mode = false


func _reflected_bullet(p: Player, offset: Vector2) -> Projectile:
	var b := Projectile.spawn(level.projectiles, Team.ENEMY, p.global_position + offset, Vector2.LEFT, DB.test_turret.projectile)
	b.reflect(Vector2.LEFT, false, DB.parry)
	b.last_swing_id = -99
	return b


func test_reparry_chain() -> void:
	var p := await _start()
	var b := _reflected_bullet(p, Vector2(14, 0))
	var dmg := b.damage
	var speed := b.velocity.length()
	input.push(Vector2.ZERO, 1, 0, InputFrame.MELEE, p.global_position + Vector2(100, 0))
	await step(1)
	check(_ev(&"reparried") == 1 and b.reflect_count == 2, "반사탄을 근접으로 다시 침 → 재패링")
	check(b.damage == dmg + DB.advanced.reparry_damage_bonus, "연쇄 강화: 데미지 +%d" % DB.advanced.reparry_damage_bonus)
	check(b.velocity.normalized().dot(Vector2.RIGHT) > 0.99 and b.velocity.length() > speed, "조준 방향으로 더 빠르게")
	await step(3)
	check(_ev(&"reparried") == 1, "같은 휘두르기로는 두 번 안 침")
	# 최대 단계: 탄을 근접 범위 안에 붙잡아 두고 휘두를 때마다 다시 친다
	for i in DB.advanced.reparry_max_chain + 2:
		b.velocity = Vector2.LEFT * 0.001
		b.lifetime = 9999
		for t in DB.melee.active_ticks + DB.melee.recovery_ticks:
			b.global_position = p.global_position + Vector2(14, 0)
			await step(1)
		input.push(Vector2.ZERO, 1, 0, InputFrame.MELEE, p.global_position + Vector2(100, 0))
		await step(1)
	check(b.reflect_count == DB.advanced.reparry_max_chain + 1, "최대 %d단계까지만 (%d)" % [DB.advanced.reparry_max_chain, b.reflect_count - 1])


func test_dash_slash() -> void:
	var p := await _start(DUMMY_MAP)
	var dummy: TargetDummy = null
	for n in level.get_node("Props").get_children():
		if n is TargetDummy:
			dummy = n
			break
	p.teleport(dummy.global_position - Vector2(60, 0))
	await step(1)
	var start := p.global_position
	var aim := dummy.global_position
	input.push(Vector2.RIGHT, 1, 0, InputFrame.DODGE, aim)
	input.push(Vector2.RIGHT, 2, 0, 0, aim)
	input.push(Vector2.RIGHT, 1, 0, InputFrame.MELEE, aim)
	await step(4)
	check(p.state == Player.State.DASH_SLASH and _ev(&"dash") == 1, "회피 중 근접 → 돌진 베기")
	check(p.is_invulnerable(), "돌진 중 무적")
	await step(DB.advanced.dash_slash_ticks + 2)
	var plain := (DB.dodge as DashDodgeData).speed * (DB.dodge as DashDodgeData).duration_ticks / 60.0
	check(p.global_position.x - start.x > plain + 8.0, "회피만 할 때(%.0fpx)보다 더 멀리: 회피 + 회피 거리만큼 돌진 (%.0fpx)" % [plain, p.global_position.x - start.x])
	check(dummy.hit_count >= 1, "돌진하며 벤다 (허수아비 명중)")
	check(p.state == Player.State.NORMAL, "끝나면 일반 상태")


func test_combo() -> void:
	var p := await _start()
	check(p.combo.stage == 0 and not p._aura.visible, "처음엔 콤보 0, 이펙트 없음")
	p._on_parried(_reflected_bullet(p, Vector2(40, 0)), true)
	check(p.combo.stage == 1 and _events.get(&"stage") == 1, "완벽 패링 → 콤보 1단계")
	p._start_stealth()
	check(p.combo.stage == 2, "완벽 회피도 이어짐 → 2단계")
	for i in 5:
		p.combo.add()
	check(p.combo.stage == DB.advanced.combo_max_stage, "최대 %d단계" % DB.advanced.combo_max_stage)
	await step(1)
	check(p._aura.visible, "캐릭터 주변 이펙트로 표시")
	p.stealth_ticks_left = 0
	var start := p.global_position
	input.push(Vector2.RIGHT, 30, 0, 0, start + Vector2(100, 0))
	await step(30)
	var expected := DB.player.move_speed * p.combo.speed_mult() * 30.0 / 60.0
	check_near(p.global_position.x - start.x, expected, 1.0, "이동속도 증가")
	input.push(Vector2.ZERO, 1, 0, InputFrame.SHOOT, p.global_position + Vector2(100, 0))
	await step(1)
	var shot: Projectile = null
	for n in level.projectiles.get_children():
		if (n as Projectile).team == Team.PLAYER and (n as Projectile).kind == HitInfo.Kind.BULLET:
			shot = n
	check(shot != null and shot.damage == ceili(DB.gun.projectile.damage * p.combo.damage_mult()), "데미지 증가 (%d)" % (shot.damage if shot else -1))
	await step(DB.advanced.combo_window_ticks)
	check(p.combo.stage == 0 and _events.get(&"stage") == 0, "시간 안에 못 이으면 초기화")


## 숨은 테크는 게임 안 글자(안내·표지판·스킬 설명·UI)에 절대 없다
func test_no_hidden_tech_text_anywhere() -> void:
	var forbidden := ["처형", "은신", "돌진 베기", "재패링", "콤보", "연쇄"]
	var texts: Array[String] = []
	for sd: TutorialSectionData in DB.game_config.tutorial.sections:
		texts.append_array([sd.hint, sd.sign_text, sd.title])
	texts.append(DB.game_config.tutorial.pre_start_hint)
	for s: SkillData in DB.skills:
		texts.append_array([s.display_name, s.tag, s.description])
	# UI 스크립트 안의 화면 문자열 (주석 제외)
	for path in ["res://ui/hud.gd", "res://ui/hint_display.gd", "res://ui/skill_panel.gd", "res://ui/result_screen.gd",
			"res://ui/run_timer.gd", "res://ui/pause_overlay.gd", "res://ui/boss_bar.gd", "res://levels/props/signpost.gd"]:
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var code := line.split("#")[0]
			var parts := code.split("\"")
			for i in range(1, parts.size() - 1, 2):
				texts.append(parts[i])
	var bad: Array[String] = []
	for t in texts:
		for w: String in forbidden:
			if t.contains(w):
				bad.append("%s ← %s" % [t, w])
	check(bad.is_empty(), "게임 안 글자에 숨은 테크 언급 없음 %s" % [bad])
