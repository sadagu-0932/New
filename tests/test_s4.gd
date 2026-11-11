extends TestBase
## S4~S7: 지역(연구소·광산촌·숲·골렘 터), 웨이스톤·지도·순간이동, NPC 대화, 골렘 2페이즈·자료 발견, 범위의 끝.

var main: Node
var _toasts: Array[String] = []
var _stories: Array[String] = []


func run_all() -> void:
	print("\n[S4~S7] 지역·웨이스톤·지도·NPC·골렘 2페이즈")
	StorySave.clear_all()
	Events.toast.connect(func(t: String) -> void: _toasts.append(t))
	Events.story_triggered.connect(func(id: String) -> void: _stories.append(id))
	test_area_data()
	await _boot()
	await test_wake_in_lab()
	await test_pickups()
	await test_waystone()
	await test_exit_to_village()
	await test_npc_dialogue()
	await test_map_and_teleport()
	await test_forest_enemies()
	await test_boss_room_rules()
	await test_golem_phase2()
	await test_document_and_ending()
	main.queue_free()
	PlayerInput.source = ScriptedInputSource.new()
	await step(2)
	StorySave.clear_all()


func test_area_data() -> void:
	for id: String in ["prologue", "lab", "village", "forest", "golem_lair"]:
		check(DB.area(id) != null, "지역 등록: %s" % id)
	var forbidden := ["처형", "은신", "돌진 베기", "재패링", "콤보", "연속"]
	var bad: Array[String] = []
	var all_ways: Array[String] = []
	for a: AreaData in DB.areas.values():
		if a.map_file.is_empty():
			continue
		var m := a.level_map()
		check(a.prop_cells("E").size() == a.exits.size() and a.prop_cells("Y").size() == a.waystones.size()
			and a.prop_cells("$").size() == a.pickups.size() and a.prop_cells("N").size() == a.npcs.size()
			and a.prop_cells("I").size() == a.signs.size(), "%s: 맵의 소품 수 = 지역 데이터 수" % a.id)
		for ex in a.exits:
			if ex.target_area.is_empty():
				continue
			var target := DB.area(ex.target_area)
			check(target != null and (ex.target_spawn == 0 or target.level_map().section_cells.has(ex.target_spawn)),
				"%s → %s: 도착 지점 %d 있음" % [a.id, ex.target_area, ex.target_spawn])
		for id: String in a.pickups:
			check(DB.item(id) != null, "%s: 획득물 %s 는 있는 아이템" % [a.id, id])
		for key: String in a.enemy_overrides.values():
			check(DB.enemies.has(key), "%s: 적 수치 %s 있음" % [a.id, key])
		for w in a.waystones:
			all_ways.append(w.id)
		var texts: Array[String] = []
		texts.append_array(a.signs)
		for n in a.npcs:
			texts.append_array(n.lines)
			texts.append_array(n.alt_lines)
		for t in texts:
			for word: String in forbidden:
				if t.contains(word):
					bad.append(t)
		check(DB.theme.load_json(a.tileset).has("tiles") and m.width > 0, "%s: 타일 그림 %s" % [a.id, a.tileset])
	check(bad.is_empty(), "지역 글·대사에 숨은 테크 단어 없음 %s" % [bad])
	check(all_ways == (["lab_exit", "village", "forest_gate", "boss_gate"] as Array[String]) or all_ways.size() == 4,
		"웨이스톤 4곳: 1지역 출구·광산촌·숲 입구·보스방 앞 %s" % [all_ways])
	check(DB.area("village").npcs.size() >= 3 and DB.area("village").prop_cells("C").is_empty() and DB.area("village").prop_cells("S").is_empty(), "광산촌: 주민 있고 적 없음")
	check(DB.area("lab").npcs.is_empty(), "1지역 연구소에는 마을(주민) 없음")
	var only_known := true
	for a: AreaData in DB.areas.values():
		if a.map_file.is_empty():
			continue
		for entry: Dictionary in a.level_map().props:
			if not Level.SPAWNS.has(entry["char"]):
				only_known = false
	check(only_known, "지역 맵은 기존 적 글자(C c S B Z)와 스토리 소품만 사용 (새 적 없음)")
	var forest_charger := DB.enemies["charger_forest"] as EnemyData
	check(forest_charger.get_script() == (DB.enemies["charger"] as EnemyData).get_script() and forest_charger.max_hp != (DB.enemies["charger"] as EnemyData).max_hp,
		"지역별 적 차이는 같은 종류의 수치(data)로만")


func _boot() -> void:
	if level != null:
		level.queue_free()
		level = null
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	await step(2)
	main.start_new_game()
	_scripted()
	await step(2)


func _scripted() -> void:
	input = ScriptedInputSource.new()
	PlayerInput.source = input


func _p() -> Player:
	return main.run.level.player


func _lv() -> Level:
	return main.run.level


func _props(type: Variant) -> Array:
	var out: Array = []
	for n in _lv().props.get_children():
		if is_instance_of(n, type):
			out.append(n)
	return out


func _kill_enemies() -> void:
	for n in get_tree().get_nodes_in_group(Enemy.GROUP):
		if not (n is Golem):
			(n as Enemy).dead = true
			n.queue_free()


func test_wake_in_lab() -> void:
	_stories.clear()
	Events.prologue_finished.emit()
	_scripted()
	await step(3)
	check(Story.area == "lab" and _lv().area.id == "lab", "프롤로그 뒤 1지역 연구소에서 깨어남")
	check(_stories.has("lab_wake"), "깨어나는 글이 흘러감")
	check(Story.inventory.skill2_unlocked(), "튜토리얼이 끝나면 스킬 칸이 하나 더 열림")
	check(StorySave.latest()["state"]["story"]["area"] == "lab", "깨어난 자리에서 자동저장")
	check(_props(Rubble).size() > 0 and _props(AreaExit).size() == 1, "부서진 벽(잔해)과 출구가 있음")
	Debug.god_mode = true
	_kill_enemies()
	await step(2)


func test_pickups() -> void:
	var pickups := _props(ItemPickup)
	check(pickups.size() == 2, "연구소 획득물 2개")
	var gun: ItemPickup = pickups[0]
	_toasts.clear()
	_p().teleport(gun.global_position)
	await step(3)
	check(Story.inventory.has("rapid_gun") and not is_instance_valid(gun) or gun.is_queued_for_deletion(), "닿으면 인벤토리에 들어감")
	check(_toasts.has(DB.story.text_item_picked % DB.item("rapid_gun").display_name), "획득 알림 %s" % [_toasts])
	# 자료는 줍자마자 펼쳐진다
	var memo: ItemPickup = pickups[1]
	_p().teleport(memo.global_position)
	await step(3)
	await get_tree().process_frame
	await get_tree().process_frame
	check(Story.inventory.has("lab_memo") and main.inventory_panel.reading, "자료를 주우면 바로 펼쳐 보여줌")
	main.inventory_panel._close_document()
	check(not main.inventory_panel.is_open and Story.has_flag("read:lab_memo") and not get_tree().paused, "닫으면 게임으로, 읽었다는 진행도 기록")
	# 주운 것은 다시 나오지 않는다
	main.travel("lab", 0)
	_scripted()
	await step(3)
	check(_props(ItemPickup).is_empty(), "한 번 주운 것은 지역에 다시 나오지 않음")
	_kill_enemies()
	await step(2)


func test_waystone() -> void:
	var stone: Waystone = _props(Waystone)[0]
	check(not stone.active and Story.waystones.is_empty(), "웨이스톤은 처음엔 비활성")
	check(MapPanel.revealed_areas().is_empty(), "활성화 전에는 지도가 전부 가려져 있음")
	var p := _p()
	p.health.current = 2
	p.ammo.set_current(1)
	var before := int(StorySave.latest()["seq"])
	_toasts.clear()
	p.teleport(stone.global_position + Vector2(0, 10))
	await step(3)
	check(stone.active and Story.waystones == ["lab_exit"], "닿으면 활성화")
	check(p.health.current == p.health.maximum and p.ammo.current == p.ammo.maximum, "활성화하면 회복 (체력·탄약)")
	check(int(StorySave.latest()["seq"]) == before + 1 and StorySave.latest()["kind"] == "auto", "활성화하면 자동저장")
	check(StorySave.latest()["state"]["story"]["waystones"] == ["lab_exit"], "저장에 활성화한 웨이스톤이 들어감")
	check(_toasts.has(DB.story.text_waystone_activated % Settings.key_name(&"map")), "활성화 알림 (지도 키 안내) %s" % [_toasts])
	check(MapPanel.revealed_areas() == (["lab"] as Array[String]), "그 주변(연구소)이 지도에서 밝혀짐")
	var seq := int(StorySave.latest()["seq"])
	await step(5)
	check(int(StorySave.latest()["seq"]) == seq, "이미 활성화한 웨이스톤은 다시 닿아도 변화 없음")


func test_exit_to_village() -> void:
	var p := _p()
	p.health.current = 3
	var ex: AreaExit = _props(AreaExit)[0]
	p.teleport(ex.global_position)
	await step(3)
	_scripted()
	await step(2)
	check(Story.area == "village" and _lv().area.id == "village", "출구를 밟으면 광산촌으로")
	p = _p()
	check(p.global_position.distance_to(DB.area("village").spawn_position(1)) < 2.0, "도착 지점(연구소 쪽 입구)에 섬")
	check(p.health.current == 3, "지역을 넘어가도 체력 그대로")
	check(get_tree().get_nodes_in_group(Enemy.GROUP).is_empty(), "광산촌에는 적이 없음")
	await step(3)
	check(Story.area == "village", "도착하자마자 되돌아가지 않음")
	check(_stories.has("village_enter"), "처음 들어온 지역의 글")


func test_npc_dialogue() -> void:
	var npcs := _props(Npc)
	check(npcs.size() == 4, "광산촌 주민 4명")
	var npc: Npc = npcs[0]
	var p := _p()
	var box: DialogueBox = main.dialogue_box
	p.teleport(npc.global_position + Vector2(0, 16))
	await step(2)
	check(npc._prompt.visible and npc._prompt.text.contains("대화"), "가까이 가면 대화 안내 (%s)" % npc._prompt.text)
	input.push(Vector2.ZERO, 1, 0, InputFrame.INTERACT)
	await step(2)
	check(box.is_open and box._speaker.text == npc.data.display_name and box._text.text == npc.data.lines[0], "상호작용 키로 대사창: %s" % box._text.text)
	check(p.cutscene_lock, "대화 중에는 주인공이 움직이지 않음")
	var tick := Game.tick
	await step(3)
	check(Game.tick > tick, "대사창이 떠 있어도 게임은 돌아감")
	for i in npc.data.lines.size() - 1:
		box.advance()
	check(box.is_open and box._text.text == npc.data.lines[npc.data.lines.size() - 1], "한 줄씩 넘김")
	box.advance()
	check(not box.is_open and not p.cutscene_lock, "마지막 줄 뒤 닫히고 다시 움직일 수 있음")
	# 대사를 넘긴 키가 같은 순간 다시 말을 걸지 않는다
	input.push(Vector2.ZERO, 1, 0, InputFrame.INTERACT)
	await step(2)
	check(not box.is_open, "대화가 끝난 직후의 키 입력으로 곧바로 다시 말을 걸지 않음")
	await step(DB.story.talk_cooldown_ticks + 2)
	input.push(Vector2.ZERO, 1, 0, InputFrame.INTERACT)
	await step(2)
	check(box.is_open, "잠시 뒤에는 다시 말을 걸 수 있음")
	box.close()
	Story.set_flag("golem_destroyed")
	check(npc.current_lines() == npc.data.alt_lines, "스토리 진행에 따라 대사가 바뀜")
	Story.flags.erase("golem_destroyed")
	# 글이 대사창(2줄)을 넘지 않는지
	var label := UiText.make_label()
	var font := label.get_theme_font(&"font")
	label.free()
	var too_long: Array[String] = []
	for a: AreaData in DB.areas.values():
		for n in a.npcs:
			for line: String in n.lines + n.alt_lines:
				if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE_SMALL).x > 264.0 * 2.0:
					too_long.append(line)
	for id: String in DB.story.lines:
		for line: String in DB.story.lines[id]:
			if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE_SMALL).x > 316.0:
				too_long.append(line)
	check(too_long.is_empty(), "대사·글이 칸 안에 들어감 %s" % [too_long])


func test_map_and_teleport() -> void:
	var panel: MapPanel = main.map_panel
	# 광산촌 웨이스톤 활성화
	var stone: Waystone = _props(Waystone)[0]
	_p().teleport(stone.global_position + Vector2(0, 10))
	await step(3)
	check(Story.waystones.has("village") and MapPanel.revealed_areas().has("village") and not MapPanel.revealed_areas().has("forest"),
		"광산촌 웨이스톤 → 광산촌이 밝혀짐, 숲은 아직 가려짐")
	check(panel.open() and get_tree().paused, "지도 열기 (게임 일시정지)")
	check(panel.targets.size() == 2, "순간이동할 수 있는 곳 = 활성화한 웨이스톤 2곳")
	check((panel.targets[panel.selected]["waystone"] as WaystoneData).id == "village", "지금 있는 곳의 웨이스톤이 골라져 있음")
	var names: Array[String] = []
	for a in MapPanel.areas():
		names.append(MapPanel.area_label(a))
	check(MapPanel.world_size().x > MapPanel.VIEW.size.x, "지도는 화면보다 넓게 펼쳐져 있음 (%d px)" % int(MapPanel.world_size().x))
	var overlap := false
	var list := MapPanel.areas()
	for i in list.size():
		for j in range(i + 1, list.size()):
			if MapPanel.area_rect(list[i]).grow(2.0).intersects(MapPanel.area_rect(list[j])):
				overlap = true
	check(not overlap, "지도에서 지역끼리 겹치지 않음")
	check(float(panel._fog["forest"]) == 1.0 and float(panel._fog["village"]) == 1.0 and Story.has_flag("map_seen:village"),
		"처음 보는 밝혀진 지역은 안개가 걷히는 것부터 보여줌, 숲은 가려진 채")
	for i in 90:
		await get_tree().process_frame
	check(float(panel._fog["village"]) < 0.3 and float(panel._fog["forest"]) == 1.0, "안개가 걷힘 (%.2f)" % float(panel._fog["village"]))
	var view := Rect2(panel.camera, MapPanel.VIEW.size)
	check(view.grow(1.0).has_point(panel.targets[panel.selected]["pos"]), "고른 탑이 지도 창 안에 보임")
	check(names.count(DB.story.text_unknown_area) == 2 and names.has("연구소") and names.has("마석 광산촌"), "가려진 지역은 이름도 가려짐 %s" % [names])
	panel._select(0)
	check((panel.targets[panel.selected]["waystone"] as WaystoneData).id == "lab_exit", "←→ 로 다른 웨이스톤 고름")
	for i in 60:
		await get_tree().process_frame
	check(Rect2(panel.camera, MapPanel.VIEW.size).grow(1.0).has_point(panel.targets[panel.selected]["pos"]), "지도가 고른 탑을 따라 움직임")
	var hp := _p().health.current
	panel.confirm()
	_scripted()
	await step(3)
	check(Story.area == "lab" and not panel.is_open and not get_tree().paused, "Enter → 연구소 출구 웨이스톤으로 순간이동")
	var stone_pos := LevelMap.cell_center(DB.area("lab").prop_cells("Y")[0])
	check(_p().global_position.distance_to(stone_pos) <= LevelMap.TILE_SIZE * 1.5 and _p().health.current == hp, "웨이스톤 옆에 도착, 체력 그대로")
	# 전투 중에는 불가
	_kill_enemies()
	await step(2)
	level = _lv()
	var e := spawn_enemy("charger_weak", _p().global_position + Vector2(40, 0))
	level = null
	await wait_until(func() -> bool: return e.has_target, 30)
	panel.open()
	panel._select(1)
	panel.confirm()
	check(Story.area == "lab" and panel.is_open and panel.current_notice() == DB.story.text_cannot_teleport, "전투 중에는 순간이동 불가 + 안내")
	check(not main.teleport("village", "village"), "전투 중 순간이동 요청은 거절")
	panel.close()
	e.dead = true
	e.queue_free()
	await step(2)
	check(not main.teleport("forest", "boss_gate"), "활성화하지 않은 웨이스톤으로는 갈 수 없음")
	check(main.teleport("village", "village"), "전투가 끝나면 순간이동 가능")
	_scripted()
	await step(3)
	check(Story.area == "village", "광산촌으로 돌아옴")


func test_forest_enemies() -> void:
	main.travel("forest", 1)
	_scripted()
	await step(3)
	check(_lv().area.id == "forest", "숲")
	var kinds := {}
	var only_three := true
	for n in get_tree().get_nodes_in_group(Enemy.GROUP):
		var e := n as Enemy
		kinds[(e.get_script() as Script).get_global_name()] = true
		if not (e is Charger or e is Shooter or e is Spreader):
			only_three = false
	check(only_three and kinds.size() == 3, "숲의 적은 기존 3종의 조합 %s" % [kinds.keys()])
	var charger: Enemy = null
	for n in get_tree().get_nodes_in_group(Enemy.GROUP):
		if n is Charger:
			charger = n
	check(charger.data == DB.enemies["charger_forest"], "숲의 돌진형은 숲용 수치를 씀")
	check(_props(Waystone).size() == 2, "숲 입구와 보스방 앞에 웨이스톤")
	_kill_enemies()
	await step(2)
	# 나무는 근접으로 베어 지나갈 수 있다
	var lv := _lv()
	check(lv.breakable != null, "숲: 나무를 벨 수 있는 지역")
	var tree := Vector2i(13, 5)
	check(lv.map.is_wall(tree) and lv.breakable.can_break(tree) and not lv.breakable.can_break(Vector2i(0, 0)), "안쪽 나무는 벨 수 있고 맵 테두리는 못 벰")
	var p := _p()
	p.teleport(LevelMap.cell_center(Vector2i(11, 5)))
	await step(2)
	var before := p.global_position
	input.push(Vector2.RIGHT, 30)
	await step(31)
	check(p.global_position.x < LevelMap.cell_center(tree).x - 8.0, "베기 전에는 나무에 막힘")
	var wood := Story.inventory.count("wood")
	var swings := 0
	while lv.map.is_wall(tree) and swings < 6:
		p.teleport(LevelMap.cell_center(Vector2i(12, 5)))
		input.push(Vector2.ZERO, 1, 0, InputFrame.MELEE, LevelMap.cell_center(tree))
		await step(p.weapon.melee.active_ticks + p.weapon.melee.recovery_ticks + 3)
		swings += 1
	check(not lv.map.is_wall(tree) and swings == DB.area("forest").break_hits, "근접으로 %d번 치면 나무가 베어짐" % swings)
	check(Story.inventory.count("wood") > wood, "벤 나무에서 나무토막을 얻음")
	p.teleport(LevelMap.cell_center(Vector2i(12, 5)))
	input.push(Vector2.RIGHT, 30, 0, 0, LevelMap.cell_center(tree))
	await step(31)
	check(p.global_position.x > LevelMap.cell_center(tree).x - 4.0, "벤 자리로 지나갈 수 있음 (x=%.0f)" % p.global_position.x)
	var walls := lv.tiles.get_node(LevelBuilder.WALLS) as TileMapLayer
	check(walls.get_cell_source_id(tree) == -1, "벤 칸의 벽 타일이 사라짐 (그루터기만 남음)")
	p.teleport(before)
	await step(2)
	var gate: Waystone = _props(Waystone)[1]
	_p().teleport(gate.global_position + Vector2(0, 10))
	await step(3)
	check(Story.waystones.has("boss_gate") and MapPanel.revealed_areas().has("golem_lair"), "보스방 앞 웨이스톤 → 골렘 터까지 지도에 밝혀짐")
	check(StorySave.latest()["state"]["story"]["waystones"].has("boss_gate"), "보스방 앞에서 자동저장")


func test_boss_room_rules() -> void:
	main.travel("golem_lair", 1)
	_scripted()
	await step(3)
	check(_lv().area.id == "golem_lair" and DB.area("golem_lair").is_restricted(), "골렘 터 = 보스방")
	var g := _golem()
	check(g != null and g.data == DB.enemies["golem_worn"] and g.mode == Golem.Mode.DORMANT, "지친 골렘이 있음 (아직 깨어나지 않음)")
	check(not CombatState.in_combat(get_tree()) and CombatState.is_restricted(get_tree()), "골렘이 깨기 전에도 보스방은 제한 구역")
	var before := int(StorySave.latest()["seq"])
	check(not main.saves.save_manual() and not main.saves.save_auto("timer") and int(StorySave.latest()["seq"]) == before, "보스방에서는 수동·자동 저장 모두 불가")
	check(not main.teleport("village", "village"), "보스방에서는 순간이동 불가")
	var exits := _props(AreaExit)
	check((exits[0] as AreaExit).is_locked(), "3지역으로 가는 길은 아직 잠겨 있음")


func _golem() -> Golem:
	for n in get_tree().get_nodes_in_group(Enemy.GROUP):
		if n is Golem:
			return n
	return null


func test_golem_phase2() -> void:
	var g := _golem()
	var d := g.gd()
	var p := _p()
	Debug.god_mode = true
	p.teleport(g.global_position + Vector2(0, 70))
	await step(2)
	check(g.mode == Golem.Mode.INTRO and CombatState.in_combat(get_tree()), "가까이 가면 깨어남")
	await wait_until(func() -> bool: return g.mode == Golem.Mode.FIGHT, d.intro_ticks + 5)
	check(g.phase is GolemPhase2 and g.phase.number() == 2, "곧바로 2페이즈 (기존 페이즈 상태 구조)")
	check(d.max_hp < (DB.enemies["golem"] as GolemData).max_hp, "동력이 바닥난 상태: 체력이 낮아 짧은 전투 (%d)" % d.max_hp)
	await wait_until(func() -> bool: return (g.phase as GolemPhase2).history.size() >= 3, d.p2_rest_ticks * 4 + d.p2_aimed_interval_ticks * d.p2_aimed_shots * 3 + 60)
	check((g.phase as GolemPhase2).history == ([GolemPhase2.Pattern.AIMED, GolemPhase2.Pattern.AIMED, GolemPhase2.Pattern.RING] as Array[int]),
		"2페이즈 패턴은 정해진 순서 (랜덤 없음) %s" % [(g.phase as GolemPhase2).history])
	# 일반 탄은 거의 안 들어가고, 반사탄이 코어를 부순다
	var hp := g.hp
	g.hurtbox.receive_hit(HitInfo.make(1, HitInfo.Kind.BULLET, Team.PLAYER, Vector2.RIGHT, null))
	check(g.hp == hp, "일반 탄 한 발로는 깎이지 않음")
	g.hp = 1
	g.hurtbox.receive_hit(HitInfo.make(DB.parry.reflect_damage, HitInfo.Kind.REFLECT, Team.PLAYER, Vector2.RIGHT, null))
	check(g.mode == Golem.Mode.COLLAPSE and g.defeated, "반사탄으로 코어를 부수면 붕괴 시작 (컷씬 없음)")
	check(_props(GolemCutscene).is_empty(), "2페이즈 격파에는 컷씬이 없음")
	await wait_until(func() -> bool: return g.mode == Golem.Mode.WRECK, d.collapse_ticks + 5)
	check(g.mode == Golem.Mode.WRECK and Story.has_flag("golem_destroyed"), "무너져 잔해가 됨, 진행도 기록")
	check(not CombatState.is_restricted(get_tree()), "쓰러뜨린 뒤에는 보스방 제한이 풀림")
	check(_props(ItemPickup).size() == 1 and (_props(ItemPickup)[0] as ItemPickup).item_id == "golem_record", "골렘 몸에서 자료가 떨어짐")
	check(not Story.inventory.has("golem_record") and not _stories.has("read:golem_record"), "전투 중에는 진실이 드러나지 않음 (자료를 읽기 전)")
	Debug.god_mode = false


func test_document_and_ending() -> void:
	var p := _p()
	var drop: ItemPickup = _props(ItemPickup)[0]
	_stories.clear()
	p.teleport(drop.global_position)
	await step(3)
	await get_tree().process_frame
	await get_tree().process_frame
	check(Story.inventory.has("golem_record") and main.inventory_panel.reading, "자료를 주우면 펼쳐짐")
	var text: String = main.inventory_panel._doc_text.text
	check(text.contains("폭주") and text.contains("연구소"), "자료에 진실이 적혀 있음 (폭주한 실험체, 다른 연구소들)")
	check(not _stories.has("read:golem_record"), "아직 읽는 중")
	main.inventory_panel._close_document()
	check(Story.has_flag("read:golem_record") and _stories.has("read:golem_record"), "자료를 읽고 나서야 처음 밝혀짐")
	# 인벤토리에서 다시 읽을 수 있다
	main.inventory_panel.open()
	check(main.inventory_panel.ids(InventoryPanel.KIND_BAG).has("golem_record"), "골렘이 떨어뜨린 자료는 인벤토리에서 다시 읽을 수 있는 문서 아이템")
	main.inventory_panel.close()
	check(main.saves.save_manual(), "쓰러뜨린 뒤에는 보스방에서도 저장 가능")
	# 다시 들어와도 골렘은 잔해
	main.load_save(StorySave.latest())
	_scripted()
	await step(3)
	var g := _golem()
	check(g != null and g.mode == Golem.Mode.WRECK and not CombatState.in_combat(get_tree()), "불러와도 골렘은 잔해로 남아 있음")
	check(_props(ItemPickup).is_empty(), "이미 주운 자료는 다시 떨어져 있지 않음")
	# 3지역으로 가는 길
	var road: AreaExit = _props(AreaExit)[0]
	check(not road.is_locked(), "자료를 읽으면 3지역으로 가는 길이 열림")
	_p().teleport(road.global_position)
	await step(3)
	check(main.run == null and main._notice_layer.visible and main._notice.text.contains("3지역"), "3지역으로 가는 길 입구 = 이번 범위의 끝")
	await wait_until(func() -> bool: return main.title.is_showing(), int(DB.story.end_seconds * 60.0) + 30)
	check(main.title.is_showing() and main.title.can_continue, "끝 글 뒤 타이틀로 (이어하기 가능)")
