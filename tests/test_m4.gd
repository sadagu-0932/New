class_name TestM4
extends TestBase
## M4 자동 테스트: 튜토리얼 7구간 맵 조립, 구간 입장(스플릿)·안내 문구, 탄약 0 구간,
## 문(적 전멸·수정 스위치), 가시·바위·구덩이, 스토리 트리거(데모 비활성), 숨은 테크 문구 금지

var _events: Dictionary = {}
var _sections: Array[int] = []
var _last_hint: String = "(없음)"
var _conns: Array = []


func run_all() -> void:
	print("[M4] 튜토리얼 7구간")
	_conns = [
		[Events.section_entered, func(i: int) -> void: _sections.append(i)],
		[Events.hint_changed, func(t: String) -> void: _last_hint = t],
		[Events.gate_opened, func(_k: int) -> void: _count(&"gate")],
		[Events.story_triggered, func(_id: String) -> void: _count(&"story")],
		[Events.player_hit, func(_h: HitInfo) -> void: _count(&"hit")],
	]
	for c: Array in _conns:
		(c[0] as Signal).connect(c[1])
	test_hints_do_not_reveal_hidden_tech()
	await test_map_assembled()
	await test_sections_and_hints()
	await test_hint_hides_after_action()
	await test_drain_ammo()
	await test_gate_clear()
	await test_gate_blocks_until_open()
	await test_gate_switch()
	await test_pit_blocks_player_not_bullets()
	await test_spikes()
	await test_boulders()
	await test_story_trigger_demo_mode()
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
	await new_tutorial_level()
	_events.clear()
	_sections.clear()
	return level.player


func _section_start(k: int) -> Vector2:
	return LevelMap.cell_center(level.map.section_cells[k])


func _data(k: int) -> TutorialSectionData:
	return DB.game_config.tutorial.sections[k - 1]


## 숨은 테크는 게임 안 어디에도 안내하지 않는다 (CLAUDE.md)
func test_hints_do_not_reveal_hidden_tech() -> void:
	var forbidden := ["처형", "은신", "돌진 베기", "돌진베기", "재패링", "다시 튕", "연쇄", "콤보", "연속", "E 키", "E키", "E 를", "E로", "E 로"]
	var bad: Array[String] = []
	for sd: TutorialSectionData in DB.game_config.tutorial.sections:
		for word: String in forbidden:
			if sd.hint.contains(word):
				bad.append("%s ← '%s'" % [sd.hint, word])
	check(bad.is_empty(), "안내 문구에 숨은 테크 단어 없음 %s" % [bad])


func test_map_assembled() -> void:
	await _start()
	var m := level.map
	var expected_w := 1
	for sd: TutorialSectionData in DB.game_config.tutorial.sections:
		expected_w += TutorialData._read_rows(sd.map_file)[0].length()
	check(m.width == expected_w and m.height == 13, "7구간을 이어 붙인 맵 %dx%d" % [m.width, m.height])
	check(m.section_cells.size() == 7, "구간 시작 표시 7개")
	var unknown: Array[String] = []
	for e: Dictionary in m.props:
		if not Level.SPAWNS.has(e["char"]):
			unknown.append(e["char"])
	check(unknown.is_empty(), "맵의 모든 글자가 등록됨 %s" % [unknown])
	var triggers := 0
	for n in level.director.get_children():
		if n is StoryTrigger:
			triggers += 1
			check((n as StoryTrigger).story_id != "", "스토리 트리거 ID 있음 (%s)" % (n as StoryTrigger).story_id)
	check(triggers == 7, "구간마다 StoryTrigger 자리 7개")


func test_sections_and_hints() -> void:
	var p := await _start()
	check(level.director.section == 1, "시작하면 1구간")
	check(_last_hint == _data(1).hint, "1구간 안내 문구 표시")
	for k in range(2, 8):
		p.teleport(_section_start(k) + Vector2(4, 0))
		await step(2)
		check(level.director.section == k, "%d구간 입장" % k)
		if k < 7:
			check(_last_hint == _data(k).hint, "%d구간 안내 문구로 바뀜" % k)
	check(_sections == [2, 3, 4, 5, 6, 7], "구간 입장 이벤트 순서 %s" % [_sections])
	check(_last_hint == "", "7구간(보스)은 안내 문구 없음")
	p.teleport(_section_start(2))
	await step(2)
	check(level.director.section == 7, "뒤로 가도 구간은 되돌아가지 않음")


func test_hint_hides_after_action() -> void:
	var p := await _start()
	check(_last_hint == _data(1).hint, "안내 문구 표시 중")
	input.push(Vector2.RIGHT, 1, 0, InputFrame.DODGE, p.global_position + Vector2(50, 0))
	await step(1)
	check(_last_hint == _data(1).hint, "행동 직후엔 잠깐 유지")
	await step(_data(1).hint_hide_delay_ticks + 1)
	check(_last_hint == "", "회피를 해 보면 안내 문구가 사라짐 (게임은 멈추지 않음)")


func test_drain_ammo() -> void:
	var p := await _start()
	check(p.ammo.current == DB.gun.start_ammo, "처음엔 탄약 가득")
	p.teleport(_section_start(3) + Vector2(4, 0))
	await step(2)
	check(p.ammo.current == 0, "3구간(근접) 입장 → 탄약 0")


func _gates(k: int) -> Array:
	return level.director.contents(k)["gates"]


func test_gate_clear() -> void:
	await _start()
	var gates := _gates(2)
	check(gates.size() == 3 and not (gates[0] as Gate).is_open, "2구간 출구 문 3칸, 처음엔 닫힘")
	var enemies: Array = level.director.contents(2)["enemies"]
	check(enemies.size() == 4, "2구간 적 4마리")
	for i in enemies.size():
		var e := enemies[i] as Enemy
		e.hurtbox.receive_hit(HitInfo.make(99, HitInfo.Kind.BULLET, Team.PLAYER, Vector2.RIGHT, null))
		await step(1)
		if i < enemies.size() - 1:
			check(not (gates[0] as Gate).is_open, "적이 남아 있으면 닫힘 (%d/%d 처치)" % [i + 1, enemies.size()])
	check((gates[0] as Gate).is_open and _ev(&"gate") == 1, "적 전멸 → 문 열림")


func test_gate_blocks_until_open() -> void:
	var p := await _start()
	var gate := _gates(2)[1] as Gate
	p.teleport(gate.global_position - Vector2(24, 0))
	input.push(Vector2.RIGHT, 60, 0, 0, gate.global_position)
	await step(60)
	check(p.global_position.x < gate.global_position.x - 8.0, "닫힌 문은 지나갈 수 없음")
	for g: Variant in _gates(2):
		(g as Gate).open()
	input.push(Vector2.RIGHT, 30, 0, 0, gate.global_position + Vector2(100, 0))
	await step(30)
	check(p.global_position.x > gate.global_position.x, "열린 문은 지나감")


func test_gate_switch() -> void:
	await _start()
	var sw: Array = level.director.contents(4)["switches"]
	check(sw.size() == 1, "4구간 수정 스위치 1개")
	var s := sw[0] as CrystalSwitch
	s.hurtbox.receive_hit(HitInfo.make(1, HitInfo.Kind.BULLET, Team.PLAYER, Vector2.UP, null))
	s.hurtbox.receive_hit(HitInfo.make(2, HitInfo.Kind.MELEE, Team.PLAYER, Vector2.UP, null))
	await step(1)
	check(not s.is_on and not (_gates(4)[0] as Gate).is_open, "일반 탄·근접으로는 안 켜짐")
	s.hurtbox.receive_hit(HitInfo.make(2, HitInfo.Kind.REFLECT, Team.PLAYER, Vector2.UP, null))
	await step(1)
	check(s.is_on and (_gates(4)[0] as Gate).is_open, "반사탄에 맞으면 켜지고 문 열림 (원거리형이 살아 있어도)")


func test_pit_blocks_player_not_bullets() -> void:
	var p := await _start()
	# 4구간 구덩이 맨 아래 칸(구간 기준 13열 4행) 밑에서 위로 이동
	var pit_bottom := LevelMap.cell_center(level.map.section_cells[4] + Vector2i(13, -2))
	p.teleport(pit_bottom + Vector2(0, 24))
	input.push(Vector2.UP, 40, 0, 0, pit_bottom)
	await step(40)
	check(p.global_position.y > pit_bottom.y, "구덩이는 걸어서 못 건넘 (y=%.1f)" % p.global_position.y)
	var b := Projectile.spawn(level.projectiles, Team.PLAYER, p.global_position + Vector2(0, -6), Vector2.UP, DB.gun.projectile)
	var bid := b.get_instance_id()
	await step(6)
	var still := instance_from_id(bid) as Projectile
	check(still != null and still.alive and still.global_position.y < pit_bottom.y, "탄은 구덩이 위를 지나감")


func test_spikes() -> void:
	var p := await _start()
	var spike: SpikeTrap = null
	for n in level.props.get_children():
		if n is SpikeTrap and (n as SpikeTrap).phase == 0:
			spike = n
			break
	check(spike != null, "가시 함정 있음")
	# 내려가 있을 때까지 기다렸다가 올라오는 순간 위에 서 있기
	await wait_until(func() -> bool: return not spike.is_up(), 200)
	p.teleport(spike.global_position)
	var hp := p.health.current
	await wait_until(func() -> bool: return spike.is_up(), 200)
	await step(2)
	check(p.health.current == hp - DB.spike.damage, "가시가 올라오면 피해")
	# 엇갈린 가시: 'X' 가 올라와 있을 때 'x' 는 내려가 있음
	var alt: SpikeTrap = null
	for n in level.props.get_children():
		if n is SpikeTrap and (n as SpikeTrap).phase != 0:
			alt = n
			break
	check(alt != null and alt.is_up() != spike.is_up(), "X 와 x 는 엇갈려 오르내림")


func test_boulders() -> void:
	var p := await _start()
	var spawner: BoulderSpawner = null
	for n in level.props.get_children():
		if n is BoulderSpawner:
			spawner = n
			break
	var boulders := func() -> int:
		var count := 0
		for n in level.props.get_children():
			if n is Boulder:
				count += 1
		return count
	var appeared := await wait_until(func() -> bool: return boulders.call() > 0, DB.boulder.interval_ticks + 2)
	check(appeared, "바위가 일정 간격으로 굴러옴")
	# 바위 길목에 서 있으면 맞음
	p.teleport(spawner.global_position + Vector2(0, 80))
	_events.clear()
	await wait_until(func() -> bool: return _ev(&"hit") > 0, DB.boulder.interval_ticks * 2)
	check(_ev(&"hit") > 0, "바위에 맞으면 피해")


func test_story_trigger_demo_mode() -> void:
	var p := await _start()
	p.teleport(_section_start(2))
	await step(3)
	check(_ev(&"story") == 0, "데모 모드에서는 스토리 트리거가 발동하지 않음")
	var cfg := DB.game_config
	cfg.demo_mode = false
	var p2 := await _start()
	p2.teleport(_section_start(2))
	await step(3)
	check(_ev(&"story") == 1, "데모 모드를 끄면 스토리 트리거 발동 (본편 확장용)")
	cfg.demo_mode = true
