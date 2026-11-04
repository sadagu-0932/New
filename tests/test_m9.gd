class_name TestM9
extends TestBase
## M9 자동 테스트: 리플레이 저장·복원, 실제 판 기록 → 재생 결정론, 리플레이 모드 규칙,
## 1위 리플레이 저장, 타이틀·어트랙트 흐름, 관리자 백업·초기화

var _events: Dictionary = {}
var _conns: Array = []


func run_all() -> void:
	print("[M9] 리플레이·어트랙트·관리자")
	Leaderboard.path = "user://test_leaderboard.json"
	Leaderboard.clear()
	Replay.best_path = "user://test_best_replay.json"
	Replay.delete_best()
	_conns = [
		[Events.replay_finished, func() -> void: _count(&"replay_finished")],
	]
	for c: Array in _conns:
		(c[0] as Signal).connect(c[1])
	test_roundtrip()
	await test_replay_reproduces_run()
	await test_replay_mode_rules()
	await test_best_replay_saved()
	await test_app_flow()
	test_admin()
	for c: Array in _conns:
		(c[0] as Signal).disconnect(c[1])
	Leaderboard.clear()
	Leaderboard.path = "user://leaderboard.json"
	Replay.delete_best()
	Replay.best_path = "user://best_replay.json"
	PlayerInput.use_live_input()


func _count(key: StringName) -> void:
	_events[key] = int(_events.get(key, 0)) + 1


func _ev(key: StringName) -> int:
	return int(_events.get(key, 0))


func test_roundtrip() -> void:
	var r := Replay.new()
	r.seed_value = 7
	r.skill_id = "blink"
	for i in 50:
		var f := InputFrame.new()
		f.move = Vector2(round(sin(i) * 127.0), 0.0) / 127.0
		f.aim = Vector2(i * 3, -i)
		f.held = InputFrame.SHOOT if i % 10 < 5 else 0
		f.pressed = InputFrame.DODGE if i == 20 else 0
		r.frames.append(f)
	for i in 30:
		r.frames.append(r.frames[r.frames.size() - 1].duplicate_frame())
	var d := r.to_dict()
	var back := Replay.from_dict(JSON.parse_string(JSON.stringify(d)))
	var same := back.frames.size() == r.frames.size() and back.seed_value == 7 and back.skill_id == "blink"
	for i in r.frames.size():
		var a := r.frames[i]
		var b := back.frames[i]
		if a.move != b.move or a.aim != b.aim or a.held != b.held or a.pressed != b.pressed:
			same = false
	check(same, "리플레이 저장 → 복원 결과가 정확히 같음")
	check((d["runs"] as Array).size() < r.frames.size(), "같은 입력은 묶어서 저장 (%d틱 → %d묶음)" % [r.frames.size(), (d["runs"] as Array).size()])


## 장면 상태 요약 (재현 비교용)
func _snapshot(run: RunController) -> String:
	var p := run.level.player
	var parts: Array[String] = ["tick=%d" % Game.tick, "p=%s" % p.global_position, "hp=%d" % p.health.current,
		"ammo=%d" % p.ammo.current, "sec=%d" % run.level.director.section, "rng=%d" % Game.rng.get_state()]
	for e in get_tree().get_nodes_in_group(Enemy.GROUP):
		parts.append("%s/%d" % [(e as Enemy).global_position, (e as Enemy).hp])
	parts.append("bullets=%d" % level_projectiles(run))
	return " ".join(parts)


func level_projectiles(run: RunController) -> int:
	return run.level.projectiles.get_child_count()


func _play_script(src: ScriptedInputSource, start: Vector2) -> void:
	var aim := start + Vector2(120, 0)
	src.push(Vector2.RIGHT, 40, 0, 0, aim)
	src.push(Vector2.RIGHT, 1, 0, InputFrame.DODGE, aim)
	src.push(Vector2(1, -0.4).normalized(), 50, 0, 0, aim)
	src.push(Vector2.RIGHT, 1, 0, InputFrame.DODGE, aim)
	src.push(Vector2(1, 0.3).normalized(), 120, 0, 0, aim + Vector2(100, 20))
	src.push(Vector2.RIGHT, 160, InputFrame.SHOOT, InputFrame.SHOOT, aim + Vector2(320, 0))
	src.push(Vector2(0, 1), 1, 0, InputFrame.MELEE, aim + Vector2(320, 0))
	src.push(Vector2.RIGHT, 200, InputFrame.SHOOT, 0, aim + Vector2(420, 10))


func test_replay_reproduces_run() -> void:
	if level != null:
		level.queue_free()
		level = null
	Debug.god_mode = false
	var setup := RunSetup.from_config(DB.game_config)
	var live := RunController.new(setup)
	add_child(live)
	var src := ScriptedInputSource.new()
	PlayerInput.source = src
	_play_script(src, live.level.player.global_position)
	var total := src.remaining()
	await step(total + 5)
	var live_state := _snapshot(live)
	var replay := live.make_replay()
	live.queue_free()
	await step(1)
	check(replay.frames.size() >= total, "실제 판의 입력이 틱마다 기록됨 (%d틱)" % replay.frames.size())
	# 파일로 저장했다가 불러와서 재생
	replay.save("user://test_replay.json")
	var loaded := Replay.load_file("user://test_replay.json")
	var rp := RunController.new(RunSetup.from_config(DB.game_config), loaded)
	add_child(rp)
	await step(replay.frames.size())
	var replay_state := _snapshot(rp)
	check(live_state == replay_state, "리플레이가 실제 판을 그대로 재현 (결정론)")
	if live_state != replay_state:
		print("    실제: ", live_state)
		print("    재생: ", replay_state)
	rp.queue_free()
	await step(1)
	DirAccess.remove_absolute("user://test_replay.json")


func test_replay_mode_rules() -> void:
	var replay := Replay.new()
	replay.seed_value = DB.game_config.run_seed
	replay.skill_id = "mark"
	for i in 30:
		replay.frames.append(InputFrame.new())
	var rp := RunController.new(RunSetup.from_config(DB.game_config), replay)
	add_child(rp)
	var panel := SkillPanel.new(rp)
	add_child(panel)
	_events.clear()
	await step(1)
	check(rp.level.player.skill.data.id == "mark", "리플레이는 기록된 스킬로 재생")
	var pos := rp.level.player.global_position
	Input.action_press(&"move_right")
	await step(10)
	Input.action_release(&"move_right")
	check(rp.level.player.global_position == pos, "리플레이 중 실제 키 입력은 무시")
	var tab := InputEventAction.new()
	tab.action = &"skill_menu"
	tab.pressed = true
	panel._unhandled_input(tab)
	check(not panel.is_open, "리플레이 중 스킬 창 안 열림")
	await step(25)
	check(_ev(&"replay_finished") == 1, "입력을 다 쓰면 재생 종료 → 타이틀")
	panel.queue_free()
	rp.queue_free()
	await step(1)


func test_best_replay_saved() -> void:
	Leaderboard.clear()
	Replay.delete_best()
	var rp := RunController.new(RunSetup.from_config(DB.game_config))
	add_child(rp)
	var screen := ResultScreen.new(rp)
	add_child(screen)
	await step(1)
	var r := RunResult.new()
	r.total_ticks = 3000
	r.cleared = true
	r.skill_id = "shockwave"
	r.split_ticks = [0, 100, 200, 300, 400, 500, 600]
	r.replay = Replay.new()
	r.replay.total_ticks = 3000
	for i in 40:
		r.replay.frames.append(InputFrame.new())
	rp.showing_result = true
	Events.run_finished.emit(r)
	screen.confirm_initials()
	var best := Replay.load_best()
	check(best != null and best.frames.size() == 40 and best.initials == "AAA", "1위 등록 → 리플레이 저장 (어트랙트용)")
	screen.close_to_title()
	screen.queue_free()
	rp.queue_free()
	await step(1)


func test_app_flow() -> void:
	var app: Node = load("res://main.tscn").instantiate()
	add_child(app)
	await step(1)
	check(app.title.is_showing() and app.run == null, "처음엔 타이틀")
	app.start_live()
	await step(1)
	check(app.run != null and app.run.mode == RunController.Mode.LIVE and not app.title.is_showing(), "아무 키 → 실제 플레이")
	app.go_title()
	await step(1)
	check(app.title.is_showing() and app.run == null, "타이틀로 돌아옴")
	# 어트랙트: 1위 리플레이가 있으면 가만히 두면 재생
	var fired := [false]
	app.title.attract_requested.connect(func() -> void: fired[0] = true, CONNECT_ONE_SHOT)
	app.title._process(DB.game_config.attract_idle_seconds + 1.0)
	check(fired[0], "타이틀에서 %d초 가만히 → 어트랙트 모드" % int(DB.game_config.attract_idle_seconds))
	await step(1)
	check(app.is_replaying(), "1위 기록 리플레이 재생")
	Events.replay_finished.emit()
	await step(1)
	check(app.title.is_showing() and not app.is_replaying(), "재생이 끝나면 타이틀")
	app.queue_free()
	await step(1)
	get_tree().paused = false


func test_admin() -> void:
	Leaderboard.clear()
	var r := RunResult.new()
	r.total_ticks = 1234
	r.skill_id = "blink"
	Leaderboard.submit("ADM", r)
	var admin := AdminPanel.new()
	add_child(admin)
	var dest := admin.backup()
	check(not dest.is_empty() and FileAccess.file_exists(dest), "관리자: 리더보드 백업 파일 생성")
	admin.press_clear()
	check(Leaderboard.load_entries().size() == 1, "초기화는 한 번 눌러서는 안 됨")
	admin.press_clear()
	check(Leaderboard.load_entries().is_empty() and Replay.load_best() == null, "두 번 누르면 리더보드·1위 리플레이 초기화")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F12
	ev.keycode = KEY_F12
	ev.ctrl_pressed = true
	ev.shift_pressed = true
	ev.pressed = true
	check(ev.is_action(&"admin_menu") and not ev.is_action(&"debug_hitboxes"), "Ctrl+Shift+F12 = 관리자 메뉴")
	DirAccess.remove_absolute(dest)
	admin.queue_free()
