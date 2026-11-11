extends TestBase
## S2: 저장 시스템 — 칸 6개(수동 1 + 자동 5), 자동저장(시작·주기·변화 검사), 수동 저장, 전투 중 금지, 불러오기, 부활.

var main: Node


func run_all() -> void:
	print("\n[S2] 저장 시스템")
	StorySave.clear_all()
	test_slots()
	await test_new_game_autosave()
	await test_timer_autosave()
	await test_no_save_in_combat()
	await test_manual_save_and_load()
	await test_respawn_at_last_save()
	await test_menus()
	StorySave.clear_all()


func test_slots() -> void:
	check(DB.save.auto_slots + 1 == 6, "저장 칸 총 6개 (수동 1 + 자동 %d)" % DB.save.auto_slots)
	check(is_equal_approx(DB.save.autosave_interval_seconds, 300.0), "자동저장 검사 주기 5분")
	for i in 5:
		StorySave.write_auto({"hp": i, "story": {"area": "prologue"}})
	StorySave.write_manual({"hp": 100, "story": {"area": "prologue"}})
	var all := StorySave.list()
	check(all.size() == 6, "6칸 모두 참")
	check(int(all[0]["state"]["hp"]) == 100 and int(all[5]["state"]["hp"]) == 0, "목록: 최신이 맨 위, 가장 오래된 것이 맨 아래")
	var ordered := true
	for i in all.size() - 1:
		if int(all[i]["seq"]) <= int(all[i + 1]["seq"]):
			ordered = false
	check(ordered, "저장 순서대로 정렬")
	# 자동저장을 더 하면 가장 오래된 자동 칸부터 사라진다. 수동 칸은 그대로
	StorySave.write_auto({"hp": 5, "story": {"area": "prologue"}})
	StorySave.write_auto({"hp": 6, "story": {"area": "prologue"}})
	all = StorySave.list()
	var hps: Array = []
	for d in all:
		hps.append(int(d["state"]["hp"]))
	check(all.size() == 6 and hps == [6, 5, 100, 4, 3, 2], "오래된 자동저장(0·1)부터 사라지고 수동은 남음 %s" % [hps])
	check(String(all[0]["saved_at"]).length() == 16, "날짜·시간 기록: %s" % all[0]["saved_at"])
	check(SaveListPanel.row_text(all[2]).begins_with("[수동]") and SaveListPanel.row_text(all[0]).contains("프롤로그"),
		"목록 글: %s" % SaveListPanel.row_text(all[2]))
	StorySave.clear_all()
	check(not StorySave.has_any() and StorySave.latest().is_empty(), "전부 지우면 저장 없음")


func _boot() -> void:
	if level != null:
		level.queue_free()
		level = null
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	await step(2)


func _use_scripted_input() -> void:
	input = ScriptedInputSource.new()
	PlayerInput.source = input


func _player() -> Player:
	return main.run.level.player


func test_new_game_autosave() -> void:
	await _boot()
	check(not main.title.can_continue, "저장이 없으면 이어하기 불가")
	main.start_new_game()
	_use_scripted_input()
	await step(2)
	var all := StorySave.list()
	check(all.size() == 1 and all[0]["kind"] == "auto", "새 게임을 시작하자마자 입구에서 자동저장")
	var pos: Array = all[0]["state"]["pos"]
	check(Vector2(pos[0], pos[1]).distance_to(_player().global_position) < 1.0, "저장 위치 = 시작 위치")
	check(int(all[0]["state"]["hp"]) == DB.player.max_hp and String(all[0]["state"]["story"]["area"]) == "prologue", "체력·지역 저장")


func test_timer_autosave() -> void:
	var mgr: StorySaveManager = main.saves
	var interval := mgr.interval_ticks()
	check(interval == 300 * 60, "5분 = %d틱" % interval)
	# 제자리에 있으면 검사만 하고 건너뜀
	mgr._ticks = interval - 2
	await step(4)
	check(StorySave.list().size() == 1 and mgr._ticks < 10, "좌표·인벤토리가 그대로면 자동저장 건너뜀")
	# 움직였으면 저장
	_player().teleport(_player().global_position + Vector2(40, 0))
	check(mgr.has_changed(), "움직이면 변화 감지")
	mgr._ticks = interval - 2
	await step(4)
	check(StorySave.list().size() == 2, "좌표가 변했으면 자동저장")
	# 인벤토리만 변해도 저장
	Story.inventory.add("mana_shard")
	check(mgr.has_changed(), "인벤토리 변화 감지")
	mgr._ticks = interval - 2
	await step(4)
	check(StorySave.list().size() == 3 and StorySave.latest()["state"]["story"]["inventory"]["items"].has("mana_shard"), "인벤토리가 변했으면 자동저장")
	Story.inventory.remove("mana_shard")


func test_no_save_in_combat() -> void:
	var mgr: StorySaveManager = main.saves
	var p := _player()
	level = main.run.level
	var e := spawn_enemy("charger_weak", p.global_position + Vector2(40, 0))
	level = null
	Debug.god_mode = true
	await wait_until(func() -> bool: return e.has_target, 30)
	var before := StorySave.list().size()
	check(not mgr.can_save() and not mgr.save_manual(), "전투 중에는 수동 저장 불가")
	check(not mgr.save_auto("waystone"), "전투 중에는 자동저장도 불가")
	p.teleport(p.global_position + Vector2(0, 30))
	mgr._ticks = mgr.interval_ticks() - 1
	await step(5)
	check(StorySave.list().size() == before, "전투 중이면 주기가 돼도 저장하지 않음")
	e.dead = true
	e.queue_free()
	await step(3)
	check(StorySave.list().size() == before + 1, "전투가 끝나면 미뤄 둔 자동저장")
	Debug.god_mode = false


func test_manual_save_and_load() -> void:
	var mgr: StorySaveManager = main.saves
	var p := _player()
	p.teleport(LevelMap.cell_center(main.run.level.map.section_cells[2] + Vector2i(1, 0)))
	await step(3)
	p.health.current = 3
	p.ammo.set_current(7)
	Story.inventory.set_skill(Inventory.SLOT_Q, "blink")
	Story.set_flag("test_flag")
	var where := p.global_position
	check(mgr.save_manual(), "수동 저장")
	var manual: Dictionary = {}
	for d in StorySave.list():
		if d["kind"] == "manual":
			manual = d
	check(not manual.is_empty() and StorySave.latest()["slot"] == "manual", "수동 칸에 저장, 최신 저장이 됨")
	# 상태를 바꾼 뒤 불러오기
	p.teleport(where + Vector2(100, 0))
	p.health.current = 1
	Story.flags.clear()
	main.load_save(manual)
	_use_scripted_input()
	await step(4)
	p = _player()
	check(p.global_position.distance_to(where) < 2.0, "불러오기: 위치 복원")
	check(p.health.current == 3 and p.ammo.current == 7, "불러오기: 체력·탄약 복원 (%d, %d)" % [p.health.current, p.ammo.current])
	check(p.skill.data.id == "blink" and Story.has_flag("test_flag"), "불러오기: 스킬·스토리 진행도 복원")
	check(not main.saves.has_changed(), "불러온 직후엔 변화 없음으로 봄")
	# 근접 구간(3구간, 입장 시 탄약 0) 안에서 저장한 탄약도 그대로 돌아오는지
	p.teleport(LevelMap.cell_center(main.run.level.map.section_cells[3] + Vector2i(1, 0)))
	await step(3)
	Debug.god_mode = true
	for n in get_tree().get_nodes_in_group(Enemy.GROUP):
		if not (n is Golem):
			(n as Enemy).dead = true
			n.queue_free()
	await step(2)
	p.ammo.set_current(5)
	check(mgr.save_manual(), "3구간 안에서 저장")
	main.load_save(StorySave.latest())
	_use_scripted_input()
	await step(4)
	check(_player().ammo.current == 5, "3구간에서 불러와도 탄약이 저장한 값 (%d)" % _player().ammo.current)
	Debug.god_mode = false


func test_respawn_at_last_save() -> void:
	var p := _player()
	var saved_pos := p.global_position
	p.teleport(saved_pos + Vector2(30, 0))
	await step(2)
	p.health.current = 1
	Projectile.spawn(main.run.level.projectiles, Team.ENEMY, p.global_position + Vector2(12, 0), Vector2.LEFT, DB.test_turret.projectile)
	await wait_until(func() -> bool: return p.is_dead(), 20)
	check(p.is_dead(), "사망")
	var old_id: int = main.run.get_instance_id()
	await wait_until(func() -> bool: return main.run != null and main.run.get_instance_id() != old_id, DB.game_config.death_restart_delay_ticks + 10)
	_use_scripted_input()
	await step(4)
	p = _player()
	check(main.run.get_instance_id() != old_id and p.global_position.distance_to(saved_pos) < 2.0, "죽으면 마지막 저장 지점에서 부활")
	check(not p.is_dead() and p.ammo.current == 5, "부활: 저장한 상태로")


func test_menus() -> void:
	# 일시정지 메뉴
	check(StoryPauseMenu.ITEMS.has("저장") and StoryPauseMenu.ITEMS.has("불러오기") and StoryPauseMenu.ITEMS.has("타이틀로"), "일시정지 메뉴에 저장·불러오기·타이틀로")
	main.run.set_paused(true)
	await get_tree().process_frame
	check(main.pause_menu.is_showing(), "일시정지 → 메뉴")
	var before := int(StorySave.latest()["seq"])
	main.pause_menu.activate(StoryPauseMenu.Item.SAVE)
	check(int(StorySave.latest()["seq"]) == before + 1 and StorySave.latest()["kind"] == "manual", "메뉴의 저장 → 수동 저장")
	main.pause_menu.activate(StoryPauseMenu.Item.LOAD)
	check(main.save_list.is_open and main.save_list.saves.size() == StorySave.list().size(), "메뉴의 불러오기 → 저장 목록")
	check(int(main.save_list.saves[0]["seq"]) == int(StorySave.latest()["seq"]), "목록 맨 위가 최신")
	main.save_list.close()
	main.pause_menu.activate(StoryPauseMenu.Item.RESUME)
	check(not get_tree().paused and not main.pause_menu.is_showing(), "계속하기")
	main.run.set_paused(true)
	main.pause_menu.activate(StoryPauseMenu.Item.TITLE)
	await get_tree().process_frame
	check(main.title.is_showing() and main.run == null and not main.pause_menu.is_showing() and not get_tree().paused, "타이틀로")
	# 타이틀의 이어하기
	check(main.title.can_continue and main.title.selected == StoryTitleScreen.Item.CONTINUE, "저장이 있으면 이어하기 가능")
	main.title.activate(StoryTitleScreen.Item.CONTINUE)
	check(main.save_list.is_open and main.save_list.selected == 0, "이어하기 → 저장 목록 (최신이 골라져 있음)")
	main.save_list.confirm()
	_use_scripted_input()
	await step(4)
	check(main.run != null and not main.title.is_showing() and not main.save_list.is_open, "목록에서 고르면 그 저장으로 시작")
	main.queue_free()
	PlayerInput.source = ScriptedInputSource.new()
	await step(2)
