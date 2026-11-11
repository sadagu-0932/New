extends TestBase
## S1: 스토리판 분리 — 타이틀, 프롤로그(튜토리얼) 스토리화, 스피드런 기능 제거.
## 이 묶음은 story_mode 가 켜진 채로 돈다 (test_runner 가 묶음마다 맞춰 준다).

var _prologue_finished: int = 0
var _demo_finished: int = 0
var _stories: Array[String] = []


func run_all() -> void:
	print("\n[S1] 스토리판 분리·프롤로그")
	Events.prologue_finished.connect(func() -> void: _prologue_finished += 1)
	Events.demo_finished.connect(func() -> void: _demo_finished += 1)
	Events.story_triggered.connect(func(id: String) -> void: _stories.append(id))
	test_config()
	test_texts()
	await test_title()
	await test_story_triggers_and_log()
	await test_no_instant_restart()
	await test_skill_change_outside_combat()
	await test_prologue_ending()
	await test_main_flow()


func test_config() -> void:
	check(DB.game_config.story_mode and Game.is_story_mode(), "스토리판 플래그 켜짐 (data/game_config.tres)")
	var app_name := String(ProjectSettings.get_setting("application/config/name", ""))
	check(app_name == "demo-story", "게임 이름이 스피드런판(demo)과 다름: %s" % app_name)
	check(OS.get_user_data_dir().get_file() == "demo-story", "저장 폴더도 따로: %s" % OS.get_user_data_dir())
	var names: Array = []
	for entry: Array in Settings.REBINDABLE:
		names.append(entry[0])
	check(not names.has(&"restart"), "키 설정 목록에 재시작 없음")


func test_texts() -> void:
	var forbidden := ["처형", "은신", "돌진 베기", "재패링", "콤보", "연속"]
	var texts: Array[String] = [DB.story.prologue_end_text, DB.story.skill_locked_notice, DB.game_config.tutorial.pre_start_hint]
	for sd: TutorialSectionData in DB.game_config.tutorial.sections:
		texts.append(sd.hint)
		texts.append(sd.sign_text)
		check(DB.story.lines.has(sd.story_id), "구간 트리거 %s 에 제어 기록 글 있음" % sd.story_id)
		check(sd.hint.begins_with("[명령]"), "안내 문구가 제어 명령 말투: %s" % sd.hint)
	for id: String in DB.story.lines:
		for line: String in DB.story.lines[id]:
			texts.append(line)
	var bad: Array[String] = []
	for t in texts:
		for w: String in forbidden:
			if t.contains(w):
				bad.append("%s ← %s" % [t, w])
	check(bad.is_empty(), "스토리판 글에도 숨은 테크 단어 없음 %s" % [bad])
	# 글이 화면 폭(320px)을 넘지 않는지
	var label := UiText.make_label()
	var font := label.get_theme_font(&"font")
	var too_wide: Array[String] = []
	for t in texts:
		for row in t.split("\n"):
			if font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE_SMALL).x > 316.0:
				too_wide.append(row)
	label.free()
	check(too_wide.is_empty(), "글이 화면 폭 안에 들어감 %s" % [too_wide])


func test_title() -> void:
	var title := StoryTitleScreen.new()
	add_child(title)
	await get_tree().process_frame
	var counts := {"new": 0, "cont": 0}
	title.new_game_requested.connect(func() -> void: counts["new"] += 1)
	title.continue_requested.connect(func() -> void: counts["cont"] += 1)
	check(StoryTitleScreen.ITEMS == (["새 게임", "이어하기", "설정", "종료"] as Array[String]), "타이틀 항목: 새 게임 / 이어하기 / 설정 / 종료")
	title.set_visible_screen(true)
	check(title.selected == StoryTitleScreen.Item.NEW_GAME, "저장이 없으면 새 게임에서 시작")
	title._move(1)
	check(title.selected == StoryTitleScreen.Item.SETTINGS, "저장이 없으면 이어하기는 건너뜀")
	title.activate(StoryTitleScreen.Item.CONTINUE)
	check(counts["cont"] == 0, "저장이 없으면 이어하기를 고를 수 없음")
	title.activate(StoryTitleScreen.Item.SETTINGS)
	check(title.key_panel.is_open, "설정 → 키 설정 창")
	title.key_panel.close()
	title.activate(StoryTitleScreen.Item.NEW_GAME)
	check(counts["new"] == 1, "새 게임 요청")
	title.can_continue = true
	title.set_visible_screen(true)
	check(title.selected == StoryTitleScreen.Item.CONTINUE, "저장이 있으면 이어하기에서 시작")
	title.activate(StoryTitleScreen.Item.CONTINUE)
	check(counts["cont"] == 1, "이어하기 요청")
	title.queue_free()
	await get_tree().process_frame


func test_story_triggers_and_log() -> void:
	var log_view := DialoguePlayer.new()
	add_child(log_view)
	_stories.clear()
	await new_tutorial_level()
	await step(3)
	check(_stories == (["tutorial_section_1"] as Array[String]), "시작하자마자 1구간 스토리 트리거 발동 %s" % [_stories])
	var first: String = DB.story.lines["tutorial_section_1"][0]
	check(log_view.current_text() == first, "제어 기록 첫 줄 표시: %s" % log_view.current_text())
	var tick := Game.tick
	await step(DB.story.line_ticks + 40)
	check(Game.tick > tick, "글이 떠 있어도 게임은 멈추지 않음")
	check(log_view.current_text() == DB.story.lines["tutorial_section_1"][1], "다음 줄로 넘어감: %s" % log_view.current_text())
	Debug.god_mode = true
	level.player.teleport(LevelMap.cell_center(level.map.section_cells[3]))
	await step(3)
	check(_stories.has("tutorial_section_3"), "구간 입구에 가면 그 구간 트리거 발동")
	Debug.god_mode = false
	log_view.queue_free()


func _start_run() -> RunController:
	if level != null:
		level.queue_free()
		level = null
		await step(1)
	input = ScriptedInputSource.new()
	PlayerInput.source = input
	var run := RunController.new(RunSetup.from_config(DB.game_config))
	add_child(run)
	await step(1)
	return run


func test_no_instant_restart() -> void:
	var run := await _start_run()
	var first := run.level
	Input.action_press(&"restart")
	await step(DB.game_config.restart_hold_ticks + 5)
	Input.action_release(&"restart")
	check(run.level == first, "R 을 길게 눌러도 재시작하지 않음")
	check(not PlayerInput.is_recording, "입력 기록(리플레이)을 하지 않음")
	run.queue_free()
	await step(1)


func test_skill_change_outside_combat() -> void:
	var run := await _start_run()
	var p := run.level.player
	cross_start_line(p)
	await step(3)
	check(Game.clock_running, "출발선을 넘음")
	check(not CombatState.in_combat(get_tree()), "주변에 적이 없으면 전투 중 아님")
	check(run.change_skill(DB.skill_by_id("blink")) and p.skill.data.id == "blink", "출발한 뒤에도 전투 중이 아니면 스킬 변경 가능")
	# 적이 플레이어를 보면 전투 중
	var e := spawn_enemy_in(run.level, "charger_weak", p.global_position + Vector2(40, 0))
	await wait_until(func() -> bool: return e.has_target, 30)
	check(CombatState.in_combat(get_tree()), "적이 플레이어를 보면 전투 중")
	check(not run.change_skill(DB.skill_by_id("mark")) and p.skill.data.id == "blink", "전투 중에는 스킬 변경 불가")
	e.dead = true
	e.queue_free()
	await step(2)
	check(run.change_skill(DB.skill_by_id("mark")), "전투가 끝나면 다시 변경 가능")
	run.queue_free()
	await step(1)


func spawn_enemy_in(lv: Level, key: String, pos: Vector2) -> Enemy:
	level = lv
	var e := spawn_enemy(key, pos)
	level = null
	return e


func test_prologue_ending() -> void:
	SaveData.set_value(GolemCutscene.SAVE_KEY, false)
	await new_tutorial_level()
	Debug.god_mode = true
	level.player.teleport(LevelMap.cell_center(level.map.section_cells[7] + Vector2i(2, 0)))
	await step(2)
	var g: Golem = null
	for n in get_tree().get_nodes_in_group(Enemy.GROUP):
		if n is Golem:
			g = n
	check(g != null and g.mode != Golem.Mode.DORMANT and CombatState.in_combat(get_tree()), "보스방: 골렘이 깨어나면 전투 중")
	var d := g.gd()
	await wait_until(func() -> bool: return g.mode == Golem.Mode.FIGHT, d.intro_ticks + 10)
	g.hp = 1
	var hit := HitInfo.new()
	hit.kind = HitInfo.Kind.REFLECT
	hit.damage = DB.parry.reflect_damage
	hit.team = Team.PLAYER
	g.hurtbox.handler.call(hit)
	await step(2)
	var cut: GolemCutscene = null
	for n in level.props.get_children():
		if n is GolemCutscene:
			cut = n
	check(cut != null, "골렘 격파 → 컷씬")
	_prologue_finished = 0
	_demo_finished = 0
	await wait_until(func() -> bool: return cut.step == GolemCutscene.Step.TEXT,
		d.cut_awaken_ticks + d.cut_special_ticks + d.cut_collapse_ticks + d.cut_fade_ticks + 20)
	check(cut._text.visible and cut._text.text == "한나절 뒤", "암전 → \"한나절 뒤\" (TO BE CONTINUED 아님): %s" % cut._text.text)
	await wait_until(func() -> bool: return _prologue_finished > 0, d.cut_text_ticks + 5)
	check(_prologue_finished == 1 and _demo_finished == 0, "컷씬 끝 → 프롤로그 종료 이벤트 (기록 화면 없음)")
	Debug.god_mode = false
	level.queue_free()
	level = null
	await step(1)


func test_main_flow() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	await step(2)
	var kinds: Array[String] = []
	for n in main.get_children():
		kinds.append((n.get_script() as Script).get_global_name() if n.get_script() else n.get_class())
	check(kinds.has("StoryTitleScreen") and not kinds.has("TitleScreen"), "스토리판 타이틀 사용")
	var speedrun: Array[String] = []
	for k in ["RunTimer", "ResultScreen", "AdminPanel"]:
		if kinds.has(k):
			speedrun.append(k)
	check(speedrun.is_empty(), "타이머·기록 화면·관리자 창을 만들지 않음 %s" % [speedrun])
	check(main.title.is_showing() and main.run == null, "처음엔 타이틀")
	main.title.activate(StoryTitleScreen.Item.NEW_GAME)
	await step(2)
	check(main.run != null and main.run.level != null and main.run.level.tutorial != null and not main.title.is_showing(), "새 게임 → 프롤로그(튜토리얼) 시작")
	Events.prologue_finished.emit()
	await step(2)
	check(Story.has_flag("prologue_done") and Story.area == DB.story.after_prologue_area, "프롤로그 끝 → 진행도 기록, 다음 지역은 %s" % Story.area)
	check(main.run != null and main.run.level.area != null and main.run.level.area.id == "world" and main.run.level.tutorial == null
		and main.run.level.area.zone_at_pos(main.run.level.player.global_position).id == "lab",
		"\"한나절 뒤\" → 바깥 세상의 연구소에서 깨어남")
	main.queue_free()
	PlayerInput.source = ScriptedInputSource.new()
	await step(2)
