class_name TestM7
extends TestBase
## M7 자동 테스트: 시간 표기, 리더보드(정렬·동점·상위 10·저장), 스플릿 기록, 기록 화면(이니셜 입력·등록·다시 하기)

var _events: Dictionary = {}
var _conns: Array = []


func run_all() -> void:
	print("[M7] 타이머·스플릿·리더보드·기록 화면")
	Leaderboard.path = "user://test_leaderboard.json"
	Leaderboard.clear()
	SaveData.use_file("user://test_save.json", true)
	_conns = [
		[Events.run_finished, func(_r: RefCounted) -> void: _count(&"finished")],
		[Events.run_started, func() -> void: _count(&"run_started")],
	]
	for c: Array in _conns:
		(c[0] as Signal).connect(c[1])
	test_format()
	test_leaderboard()
	await test_splits_and_result()
	await test_result_screen_initials()
	await test_result_screen_not_ranked()
	for c: Array in _conns:
		(c[0] as Signal).disconnect(c[1])
	Leaderboard.clear()
	Leaderboard.path = "user://leaderboard.json"
	SaveData.use_file("user://test_save.json", true)
	SaveData.use_file("user://save.json")


func _count(key: StringName) -> void:
	_events[key] = int(_events.get(key, 0)) + 1


func _ev(key: StringName) -> int:
	return int(_events.get(key, 0))


func _result(ticks: int, skill := "shockwave") -> RunResult:
	var r := RunResult.new()
	r.total_ticks = ticks
	r.skill_id = skill
	r.cleared = true
	r.split_ticks = [0, ticks / 7, ticks * 2 / 7, ticks * 3 / 7, ticks * 4 / 7, ticks * 5 / 7, ticks * 6 / 7]
	return r


func test_format() -> void:
	check(RunResult.format_ticks(0) == "0:00.000", "0틱 = 0:00.000")
	check(RunResult.format_ticks(61) == "0:01.016", "61틱 = 0:01.016 (%s)" % RunResult.format_ticks(61))
	check(RunResult.format_ticks(60 * 125 + 30) == "2:05.500", "2분 5.5초 (%s)" % RunResult.format_ticks(60 * 125 + 30))
	check(RunResult.format_diff(-30) == "−0.500" and RunResult.format_diff(90) == "+1.500", "차이 표기 −0.500 / +1.500")
	var r := _result(700)
	check(r.segment_ticks(1) == 100 and r.segment_ticks(7) == 100, "구간별 시간 계산")


func test_leaderboard() -> void:
	Leaderboard.clear()
	check(Leaderboard.rank_for(5000) == 1, "빈 리더보드면 1위")
	check(Leaderboard.submit("aaa", _result(3000)) == 1, "등록 → 1위")
	check(Leaderboard.submit("BBB", _result(2000, "blink")) == 1, "더 빠르면 1위")
	check(Leaderboard.submit("CCC", _result(3000)) == 3, "동점이면 먼저 낸 사람이 위 (3위)")
	var e := Leaderboard.load_entries()
	check(e[0]["initials"] == "BBB" and e[1]["initials"] == "AAA" and e[0]["skill_id"] == "blink", "정렬·대문자·스킬 저장")
	for i in 12:
		Leaderboard.submit("Z%02d" % i, _result(4000 + i))
	check(Leaderboard.load_entries().size() == DB.game_config.leaderboard_size, "상위 %d명만 남김" % DB.game_config.leaderboard_size)
	check(Leaderboard.rank_for(999999) == 0, "느린 기록은 순위 밖")
	check(Leaderboard.best()["ticks"] == 2000, "1위 기록 = 스플릿 비교 기준")
	Leaderboard.clear()


func test_splits_and_result() -> void:
	if level != null:
		level.queue_free()
		level = null
	input = ScriptedInputSource.new()
	PlayerInput.source = input
	var run := RunController.new(RunSetup.from_config(DB.game_config))
	add_child(run)
	await step(1)
	level = run.level
	var p := level.player
	Debug.god_mode = true
	input.push(Vector2.RIGHT, 30, 0, 0, p.global_position + Vector2(50, 0))
	await step(30)
	for k in range(2, 8):
		p.teleport(LevelMap.cell_center(level.map.section_cells[k] + Vector2i(1, 0)))
		await step(20)
	var golem: Golem = null
	for e: Variant in level.director.contents(7)["enemies"]:
		if e is Golem:
			golem = e
	golem.hp = 1
	golem.hurtbox.receive_hit(HitInfo.make(2, HitInfo.Kind.REFLECT, Team.PLAYER, Vector2.RIGHT, null))
	var r := run.make_result()
	check(r.split_ticks.size() == 7 and r.split_ticks[0] == 0, "스플릿 7개 (1구간 = 0)")
	var increasing := true
	for i in range(1, r.split_ticks.size()):
		if r.split_ticks[i] <= r.split_ticks[i - 1]:
			increasing = false
	check(increasing and r.total_ticks >= r.split_ticks[6], "스플릿이 차례로 늘어남 %s, 총 %d" % [r.split_ticks, r.total_ticks])
	check(r.cleared and r.skill_id == DB.game_config.default_skill_id, "클리어·스킬 기록")
	Debug.god_mode = false
	level = null
	run.queue_free()
	await step(1)


func _key(unicode_char: String) -> InputEventKey:
	var k := InputEventKey.new()
	k.pressed = true
	k.unicode = unicode_char.unicode_at(0)
	k.keycode = OS.find_keycode_from_string(unicode_char.to_upper())
	return k


func _confirm() -> InputEventAction:
	var a := InputEventAction.new()
	a.action = &"menu_confirm"
	a.pressed = true
	return a


func _setup_screen() -> Array:
	if level != null:
		level.queue_free()
		level = null
	input = ScriptedInputSource.new()
	PlayerInput.source = input
	var run := RunController.new(RunSetup.from_config(DB.game_config))
	add_child(run)
	var screen := ResultScreen.new(run)
	add_child(screen)
	await step(1)
	_events.clear()
	return [run, screen]


func test_result_screen_initials() -> void:
	Leaderboard.clear()
	Leaderboard.submit("OLD", _result(2000))
	var objs := await _setup_screen()
	var run: RunController = objs[0]
	var screen: ResultScreen = objs[1]
	run.showing_result = true
	Events.run_finished.emit(_result(1500))
	check(screen.is_showing() and screen.phase == ResultScreen.Phase.INITIALS and screen.rank == 1, "1위 기록 → 이니셜 입력")
	check(get_tree().paused, "기록 화면 동안 게임 멈춤")
	check(screen._total.text == "0:25.000", "총 기록 크게 표시 (%s)" % screen._total.text)
	var diffs := 0
	for c in screen._splits.get_children():
		if (c as Label).text.contains("−") or (c as Label).text.contains("+"):
			diffs += 1
	check(screen._splits.get_child_count() == 7 and diffs == 7, "구간 7개 + 1위 대비 차이")
	for ch in ["k", "i", "m"]:
		screen._unhandled_input(_key(ch))
	check("".join(screen.initials) == "KIM", "글자 키로 이니셜 입력 (%s)" % "".join(screen.initials))
	screen._unhandled_input(_confirm())
	var e := Leaderboard.load_entries()
	check(screen.phase == ResultScreen.Phase.DONE and e[0]["initials"] == "KIM" and e[0]["ticks"] == 1500, "등록 → 리더보드 1위")
	var old_level := run.level
	screen._unhandled_input(_confirm())
	await step(1)
	check(not screen.is_showing() and not get_tree().paused and run.level != old_level, "Enter → 처음부터 다시")
	screen.queue_free()
	run.queue_free()
	await step(1)


func test_result_screen_not_ranked() -> void:
	Leaderboard.clear()
	for i in DB.game_config.leaderboard_size:
		Leaderboard.submit("T%02d" % i, _result(1000 + i))
	var objs := await _setup_screen()
	var run: RunController = objs[0]
	var screen: ResultScreen = objs[1]
	run.showing_result = true
	Events.run_finished.emit(_result(9000))
	check(screen.phase == ResultScreen.Phase.DONE and screen.rank == 0, "순위 밖이면 이니셜 입력 없이 바로 결과")
	check(screen._board.get_child_count() == DB.game_config.leaderboard_size + 1, "리더보드 10줄 표시")
	screen.close_and_restart()
	await step(1)
	screen.queue_free()
	run.queue_free()
	await step(1)
	Leaderboard.clear()
