extends TestBase
## S4~S7: 한 장으로 이어진 바깥 세상(연구소·광산촌·숲·골렘 터), 웨이스톤 탑·지도·순간이동, NPC 대화,
## 나무 베기, 골렘 2페이즈·자료 발견, 범위의 끝.

var main: Node
var world: AreaData
var _toasts: Array[String] = []
var _stories: Array[String] = []


func run_all() -> void:
	print("\n[S4~S7] 열린 세계·웨이스톤·지도·NPC·골렘 2페이즈")
	StorySave.clear_all()
	world = DB.area("world")
	Events.toast.connect(func(t: String) -> void: _toasts.append(t))
	Events.story_triggered.connect(func(id: String) -> void: _stories.append(id))
	test_world_data()
	await _boot()
	await test_wake_in_lab()
	await test_pickups()
	await test_waystone()
	await test_walk_to_village()
	await test_npc_dialogue()
	await test_map_and_teleport()
	await test_forest()
	await test_boss_room_rules()
	await test_golem_phase2()
	await test_document_and_ending()
	main.queue_free()
	PlayerInput.source = ScriptedInputSource.new()
	await step(2)
	StorySave.clear_all()


func test_world_data() -> void:
	check(DB.area("prologue") != null and world != null and DB.areas.size() == 2, "지역은 프롤로그와 바깥 세상 둘뿐 (세상은 한 장)")
	var ids: Array[String] = []
	for z in world.zones:
		ids.append(z.id)
	check(ids == (["lab", "village", "forest", "golem_lair"] as Array[String]), "세상 안의 구역: 연구소·광산촌·숲·골렘 터 %s" % [ids])
	var m := world.level_map()
	var overlap := false
	for i in world.zones.size():
		check(Rect2i(0, 0, m.width, m.height).encloses(world.zones[i].rect), "구역 %s 가 맵 안에 있음" % world.zones[i].id)
		for j in range(i + 1, world.zones.size()):
			if world.zones[i].rect.intersects(world.zones[j].rect):
				overlap = true
	check(not overlap, "구역끼리 겹치지 않음")
	check(world.prop_cells("E").size() == world.exits.size() and world.prop_cells("Y").size() == world.waystones.size()
		and world.prop_cells("$").size() == world.pickups.size() and world.prop_cells("N").size() == world.npcs.size()
		and world.prop_cells("I").size() == world.signs.size(), "맵의 소품 수 = 지역 데이터 수")
	check(world.exits.size() == 1 and world.exits[0].target_area.is_empty(), "화면이 바뀌는 출입구는 없음 — 남은 하나는 3지역으로 가는 길(끝)")
	# 걸어서 어디든: 시작점에서 모든 구역의 바닥에 닿는다 (나무를 베지 않고도)
	var seen := {m.spawn_cell: true}
	var queue: Array[Vector2i] = [m.spawn_cell]
	var blocked := "#RNY~"
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n := c + d
			if not seen.has(n) and n.x >= 0 and n.y >= 0 and n.x < m.width and n.y < m.height and not blocked.contains(m.char_at(n)):
				seen[n] = true
				queue.append(n)
	for z in world.zones:
		check(seen.has(z.rect.get_center()) or seen.has(z.rect.get_center() + Vector2i(1, 2)), "시작점에서 %s 까지 걸어서 닿음" % z.display_name)
	var ways: Array[String] = []
	for w in world.waystones:
		ways.append(w.id)
	ways.sort()
	check(ways == (["boss_gate", "forest_gate", "lab_exit", "village"] as Array[String]), "웨이스톤 탑 4곳: 연구소 출구·광산촌·숲 입구·보스방 앞 %s" % [ways])
	for id: String in world.pickups:
		check(DB.item(id) != null, "획득물 %s 는 있는 아이템" % id)
	var forbidden := ["처형", "은신", "돌진 베기", "재패링", "콤보", "연속"]
	var bad: Array[String] = []
	var texts: Array[String] = []
	texts.append_array(world.signs)
	for n in world.npcs:
		texts.append_array(n.lines)
		texts.append_array(n.alt_lines)
	for t in texts:
		for word: String in forbidden:
			if t.contains(word):
				bad.append(t)
	check(bad.is_empty(), "글·대사에 숨은 테크 단어 없음 %s" % [bad])
	var only_known := true
	var enemy_zones := {}
	for entry: Dictionary in m.props:
		if not Level.SPAWNS.has(entry["char"]):
			only_known = false
		if "CcSBZ".contains(entry["char"]):
			var z := world.zone_at(entry["cell"])
			enemy_zones[z.id if z != null else ""] = true
	check(only_known, "맵은 기존 적 글자(C c S B Z)와 스토리 소품만 사용 (새 적 없음)")
	check(not enemy_zones.has("village") and world.npcs.size() >= 3, "광산촌: 주민 있고 적 없음")
	for z in world.zones:
		check(DB.theme.load_json(z.tileset).has("tiles"), "%s: 타일 그림 %s" % [z.id, z.tileset])
		for key: String in z.enemy_overrides.values():
			check(DB.enemies.has(key), "%s: 적 수치 %s 있음" % [z.id, key])
	var forest_charger := DB.enemies["charger_forest"] as EnemyData
	check(forest_charger.get_script() == (DB.enemies["charger"] as EnemyData).get_script() and forest_charger.max_hp != (DB.enemies["charger"] as EnemyData).max_hp,
		"구역별 적 차이는 같은 종류의 수치(data)로만")


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
		if is_instance_of(n, type) and not n.is_queued_for_deletion():
			out.append(n)
	return out


func _zone() -> String:
	return _lv().area_director.zone_id


func _kill_enemies() -> void:
	for n in get_tree().get_nodes_in_group(Enemy.GROUP):
		if not (n is Golem):
			(n as Enemy).dead = true
			n.queue_free()


func _waystone(id: String) -> Waystone:
	for n in _props(Waystone):
		if (n as Waystone).data.id == id:
			return n
	return null


func _center(zone_id: String) -> Vector2:
	return LevelMap.cell_center(world.zone(zone_id).rect.get_center())


func test_wake_in_lab() -> void:
	_stories.clear()
	Events.prologue_finished.emit()
	_scripted()
	await step(3)
	check(Story.area == "world" and _lv().area == world and _zone() == "lab", "프롤로그 뒤 바깥 세상의 연구소에서 깨어남")
	check(_stories.has("lab_wake"), "깨어나는 글이 흘러감")
	check(Story.inventory.skill2_unlocked(), "튜토리얼이 끝나면 스킬 칸이 하나 더 열림")
	check(StorySave.latest()["state"]["story"]["area"] == "world" and StorySave.latest()["state"]["place"] == "연구소", "깨어난 자리에서 자동저장 (저장 목록에는 구역 이름)")
	check(_props(Rubble).size() > 0, "부서진 벽의 잔해가 있음")
	var kinds := {}
	for name: String in ["Floor", "Walls"]:
		var layer := _lv().tiles.get_node(name) as TileMapLayer
		kinds[layer.get_cell_source_id(world.zone("lab").rect.get_center())] = true
		kinds[layer.get_cell_source_id(world.zone("village").rect.position + Vector2i(1, 1))] = true
		kinds[layer.get_cell_source_id(Vector2i(1, 1))] = true
	kinds.erase(-1)
	check(kinds.size() == 3, "한 맵 안에서 구역마다 타일 그림이 다름 (연구소·마을·들판)")
	Debug.god_mode = true
	_kill_enemies()
	await step(2)


func test_pickups() -> void:
	var gun: ItemPickup = null
	var memo: ItemPickup = null
	for n in _props(ItemPickup):
		if (n as ItemPickup).item_id == "rapid_gun":
			gun = n
		elif (n as ItemPickup).item_id == "lab_memo":
			memo = n
	check(gun != null and memo != null and _props(ItemPickup).size() == world.pickups.size(), "획득물이 세상 곳곳에 놓여 있음 (%d개)" % _props(ItemPickup).size())
	_toasts.clear()
	_p().teleport(gun.global_position)
	await step(3)
	check(Story.inventory.has("rapid_gun"), "닿으면 인벤토리에 들어감")
	check(_toasts.has(DB.story.text_item_picked % DB.item("rapid_gun").display_name), "획득 알림 %s" % [_toasts])
	_p().teleport(memo.global_position)
	await step(3)
	await get_tree().process_frame
	await get_tree().process_frame
	check(Story.inventory.has("lab_memo") and main.inventory_panel.reading, "자료를 주우면 바로 펼쳐 보여줌")
	main.inventory_panel._close_document()
	check(not main.inventory_panel.is_open and Story.has_flag("read:lab_memo") and not get_tree().paused, "닫으면 게임으로, 읽었다는 진행도 기록")
	var total := world.pickups.size()
	main.load_save(StorySave.latest())
	Story.set_flag("pickup:world:%d" % world.pickups.find("rapid_gun"))
	main.travel("world", 0)
	_scripted()
	await step(3)
	check(_props(ItemPickup).size() < total, "한 번 주운 것은 다시 나오지 않음")
	_kill_enemies()
	await step(2)


func test_waystone() -> void:
	Story.waystones.clear()
	var stone := _waystone("lab_exit")
	stone.refresh()
	check(stone != null and not stone.active, "웨이스톤 탑은 처음엔 꺼져 있음")
	check(MapPanel.revealed_zones().is_empty(), "켜기 전에는 지도가 전부 안개")
	var p := _p()
	p.health.current = 2
	p.ammo.set_current(1)
	var before := int(StorySave.latest()["seq"])
	_toasts.clear()
	p.teleport(stone.global_position + Vector2(0, 10))
	await step(3)
	check(stone.active and Story.waystones == ["lab_exit"], "닿으면 켜짐")
	check(p.health.current == p.health.maximum and p.ammo.current == p.ammo.maximum, "켜면 회복 (체력·탄약)")
	check(int(StorySave.latest()["seq"]) == before + 1 and StorySave.latest()["kind"] == "auto", "켜면 자동저장")
	check(StorySave.latest()["state"]["story"]["waystones"] == ["lab_exit"], "저장에 켠 웨이스톤이 들어감")
	check(_toasts.has(DB.story.text_waystone_activated % Settings.key_name(&"map")), "알림 (지도 키 안내) %s" % [_toasts])
	check(MapPanel.revealed_zones() == (["lab"] as Array[String]), "그 주변(연구소)이 지도에서 밝혀짐")
	var lab := world.zone("lab").rect
	check(MapPanel.is_revealed(lab.get_center(), ["lab"]) and MapPanel.is_revealed(lab.end + Vector2i(2, 0), ["lab"])
		and not MapPanel.is_revealed(world.zone("forest").rect.get_center(), ["lab"]), "구역과 그 둘레만 밝혀지고 먼 곳은 안개")
	var seq := int(StorySave.latest()["seq"])
	await step(5)
	check(int(StorySave.latest()["seq"]) == seq, "이미 켠 탑은 다시 닿아도 변화 없음")
	var block := p.global_position
	p.teleport(stone.global_position + Vector2(0, 12))
	input.push(Vector2.UP, 40)
	await step(41)
	check(_p().global_position.y > stone.global_position.y + 4.0, "탑은 지나갈 수 없는 구조물")
	p.teleport(block)


func test_walk_to_village() -> void:
	# 연구소의 부서진 벽에서 걸어 나가 마을까지: 화면이 바뀌지 않는다
	var p := _p()
	var lv := _lv()
	var lab := world.zone("lab").rect
	var opening := Vector2i(lab.end.x - 1, lab.position.y + 11)
	check(lv.map.is_floor(opening), "연구소 동쪽 벽이 뚫려 있음 (부서진 벽)")
	p.teleport(LevelMap.cell_center(opening + Vector2i.LEFT))
	await step(2)
	check(_zone() == "lab", "아직 연구소 안")
	_toasts.clear()
	_stories.clear()
	input.push(Vector2.RIGHT, 90)
	await step(91)
	check(_zone() == "" and _lv() == lv and p == _p(), "걸어서 벽 밖 들판으로 — 같은 화면 그대로 (레벨·플레이어가 바뀌지 않음)")
	p.health.current = 3
	p.teleport(LevelMap.cell_center(world.zone("village").rect.position + Vector2i(-2, 9)))
	await step(2)
	input.push(Vector2.RIGHT, 60)
	await step(61)
	check(_zone() == "village" and _lv() == lv, "걸어서 광산촌으로 들어감 (화면 전환 없음)")
	check(_toasts.has("마석 광산촌") and _stories.has("village_enter"), "구역에 들어서면 이름이 뜨고, 처음이면 글이 흘러감")
	check(p.health.current == 3 and Story.area == "world", "체력 그대로, 같은 세상")
	var enemies_here := 0
	for n in get_tree().get_nodes_in_group(Enemy.GROUP):
		if world.zone_at_pos((n as Node2D).global_position) == world.zone("village"):
			enemies_here += 1
	check(enemies_here == 0, "광산촌 안에는 적이 없음")


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
	input.push(Vector2.ZERO, 1, 0, InputFrame.INTERACT)
	await step(2)
	check(not box.is_open, "대화가 끝난 직후의 키 입력으로 곧바로 다시 말을 걸지 않음")
	await step(DB.story.talk_cooldown_ticks + 2)
	input.push(Vector2.ZERO, 1, 0, InputFrame.INTERACT)
	await step(2)
	check(box.is_open, "잠시 뒤에는 다시 말을 걸 수 있음")
	box.close()
	Story.set_flag("golem_destroyed")
	var changed := false
	for n in npcs:
		if not (n as Npc).data.alt_lines.is_empty() and (n as Npc).current_lines() == (n as Npc).data.alt_lines:
			changed = true
	check(changed, "스토리 진행에 따라 대사가 바뀜")
	Story.flags.erase("golem_destroyed")
	var label := UiText.make_label()
	var font := label.get_theme_font(&"font")
	label.free()
	var too_long: Array[String] = []
	for n in world.npcs:
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
	var stone := _waystone("village")
	Story.set_flag("map_seen:lab")
	_p().teleport(stone.global_position + Vector2(0, 10))
	await step(3)
	check(Story.waystones.has("village") and MapPanel.revealed_zones().has("village") and not MapPanel.revealed_zones().has("forest"),
		"광산촌 탑 → 광산촌이 밝혀짐, 숲은 아직 안개")
	check(panel.open() and get_tree().paused, "지도 열기 (게임 일시정지)")
	check(MapPanel.world_size().x > MapPanel.VIEW.size.x and MapPanel.world_size() == Vector2(world.level_map().width, world.level_map().height) * MapPanel.tile_px(),
		"지도 = 세상 한 장 그대로, 화면보다 넓게 펼쳐짐 (%d px)" % int(MapPanel.world_size().x))
	check(panel.targets.size() == 2, "순간이동할 수 있는 곳 = 켠 탑 2곳")
	check((panel.targets[panel.selected]["waystone"] as WaystoneData).id == "village", "지금 있는 곳에서 가장 가까운 탑이 골라져 있음")
	check(MapPanel.zone_label(world.zone("lab")) == "연구소" and MapPanel.zone_label(world.zone("forest")) == DB.story.text_unknown_area, "가려진 구역은 이름도 가려짐")
	check(panel._fog_old != null and panel._fog_fade > 0.9 and Story.has_flag("map_seen:village"), "새로 밝혀진 곳은 안개가 걷히는 것부터 보여줌")
	for i in 90:
		await get_tree().process_frame
	check(panel._fog_fade < 0.05, "안개가 걷힘")
	check(Rect2(panel.camera, MapPanel.VIEW.size).grow(1.0).has_point(panel.targets[panel.selected]["pos"]), "고른 탑이 지도 창 안에 보임")
	# 크게/작게: 가장 작게 하면 세상 전체가 지도 창에 들어온다
	var start_zoom: int = panel.zoom_index
	check(is_equal_approx(MapPanel.tile_px(), float(DB.story.map_tile_px)), "처음 크기는 한 칸 %d px" % DB.story.map_tile_px)
	panel.set_zoom(0)
	check(MapPanel.world_size().x <= MapPanel.VIEW.size.x + 0.5 and MapPanel.world_size().y <= MapPanel.VIEW.size.y + 0.5,
		"가장 작게 → 세상 전체가 지도 창 안에 (%.0f×%.0f px)" % [MapPanel.world_size().x, MapPanel.world_size().y])
	for i in 60:
		await get_tree().process_frame
	var whole := Rect2(panel.camera, MapPanel.VIEW.size).grow(1.0)
	check(whole.has_point(Vector2.ZERO) and whole.has_point(MapPanel.world_size()), "전체 보기에서는 세상의 양 끝이 다 보임")
	panel.set_zoom(99)
	check(panel.zoom_index == MapPanel.zoom_levels().size() - 1 and MapPanel.tile_px() > float(DB.story.map_tile_px), "가장 크게 (한 칸 %.0f px)" % MapPanel.tile_px())
	check(is_equal_approx((panel.targets[panel.selected]["pos"] as Vector2).x, (Vector2(panel.targets[panel.selected]["cell"]).x + 0.5) * MapPanel.tile_px()), "크기를 바꿔도 탑 위치가 지도와 맞음")
	panel.set_zoom(start_zoom)
	panel._select(panel.selected + 1)
	check((panel.targets[panel.selected]["waystone"] as WaystoneData).id == "lab_exit", "←→ 로 다른 탑 고름")
	for i in 60:
		await get_tree().process_frame
	check(Rect2(panel.camera, MapPanel.VIEW.size).grow(1.0).has_point(panel.targets[panel.selected]["pos"]), "지도가 고른 탑을 따라 움직임")
	var hp := _p().health.current
	var lv := _lv()
	panel.confirm()
	await step(3)
	check(not panel.is_open and not get_tree().paused and _zone() == "lab", "Enter → 연구소 탑으로 순간이동")
	check(_lv() == lv, "같은 세상 안의 순간이동은 화면을 다시 띄우지 않음")
	check(_p().global_position.distance_to(_waystone("lab_exit").global_position) <= LevelMap.TILE_SIZE * 1.5 and _p().health.current == hp, "탑 옆에 도착, 체력 그대로")
	# 전투 중에는 불가
	level = _lv()
	var e := spawn_enemy("charger_weak", _p().global_position + Vector2(40, 0))
	level = null
	await wait_until(func() -> bool: return e.has_target, 30)
	panel.open()
	panel._select(0)
	panel.confirm()
	check(panel.is_open and panel.current_notice() == DB.story.text_cannot_teleport, "전투 중에는 순간이동 불가 + 안내")
	check(not main.teleport("village"), "전투 중 순간이동 요청은 거절")
	panel.close()
	e.dead = true
	e.queue_free()
	await step(2)
	check(not main.teleport("boss_gate"), "켜지 않은 탑으로는 갈 수 없음")
	check(main.teleport("village"), "전투가 끝나면 순간이동 가능")
	await step(3)
	check(_zone() == "village", "광산촌으로 돌아옴")


func test_forest() -> void:
	var p := _p()
	var forest := world.zone("forest")
	var kinds := {}
	var only_three := true
	var charger: Enemy = null
	for n in get_tree().get_nodes_in_group(Enemy.GROUP):
		var e := n as Enemy
		if e.dead or world.zone_at_pos(e.global_position) != forest:
			continue
		kinds[(e.get_script() as Script).get_global_name()] = true
		if not (e is Charger or e is Shooter or e is Spreader):
			only_three = false
		if e is Charger:
			charger = e
	main.load_save(StorySave.latest())
	_scripted()
	await step(3)
	p = _p()
	kinds = {}
	for n in get_tree().get_nodes_in_group(Enemy.GROUP):
		var e := n as Enemy
		if world.zone_at_pos(e.global_position) != forest:
			continue
		kinds[(e.get_script() as Script).get_global_name()] = true
		if not (e is Charger or e is Shooter or e is Spreader):
			only_three = false
		if e is Charger:
			charger = e
	check(only_three and kinds.size() == 3, "숲의 적은 기존 3종의 조합 %s (불러오면 적이 다시 나옴)" % [kinds.keys()])
	check(charger != null and charger.data == DB.enemies["charger_forest"], "숲의 돌진형은 숲용 수치를 씀")
	Debug.god_mode = true
	_kill_enemies()
	await step(2)
	# 나무는 근접으로 베어 지나갈 수 있다 (연구소 벽·마을 집은 안 됨)
	var lv := _lv()
	var tree := forest.rect.position + Vector2i(13, 5)
	check(lv.map.is_wall(tree) and lv.breakable.can_break(tree), "숲의 나무는 벨 수 있음")
	check(not lv.breakable.can_break(Vector2i(0, 5)), "세상 맨 바깥 테두리는 못 벰")
	var lab_wall := world.zone("lab").rect.position
	var house := Vector2i(-1, -1)
	var vr := world.zone("village").rect
	for y in range(vr.position.y, vr.end.y):
		for x in range(vr.position.x, vr.end.x):
			if house.x < 0 and lv.map.is_wall(Vector2i(x, y)):
				house = Vector2i(x, y)
	check(lv.map.is_wall(lab_wall) and not lv.breakable.can_break(lab_wall) and house.x >= 0 and not lv.breakable.can_break(house), "연구소 벽과 마을 집은 벨 수 없음")
	var field_tree := Vector2i(-1, -1)
	for y in range(3, lv.map.height - 3):
		for x in range(3, lv.map.width - 3):
			if field_tree.x < 0 and lv.map.is_wall(Vector2i(x, y)) and world.zone_at(Vector2i(x, y)) == null:
				field_tree = Vector2i(x, y)
	check(field_tree.x >= 0 and lv.breakable.can_break(field_tree), "들판의 나무도 벨 수 있음")
	p.teleport(LevelMap.cell_center(tree + Vector2i(-2, 0)))
	await step(2)
	input.push(Vector2.RIGHT, 30)
	await step(31)
	check(p.global_position.x < LevelMap.cell_center(tree).x - 8.0, "베기 전에는 나무에 막힘")
	var wood := Story.inventory.count("wood")
	var swings := 0
	while lv.map.is_wall(tree) and swings < 6:
		p.teleport(LevelMap.cell_center(tree + Vector2i.LEFT))
		input.push(Vector2.ZERO, 1, 0, InputFrame.MELEE, LevelMap.cell_center(tree))
		await step(p.weapon.melee.active_ticks + p.weapon.melee.recovery_ticks + 3)
		swings += 1
	check(not lv.map.is_wall(tree) and swings == world.break_hits, "근접으로 %d번 치면 나무가 베어짐" % swings)
	check(Story.inventory.count("wood") > wood, "벤 나무에서 나무토막을 얻음")
	p.teleport(LevelMap.cell_center(tree + Vector2i.LEFT))
	input.push(Vector2.RIGHT, 30, 0, 0, LevelMap.cell_center(tree))
	await step(31)
	check(p.global_position.x > LevelMap.cell_center(tree).x - 4.0, "벤 자리로 지나갈 수 있음")
	check((lv.tiles.get_node(LevelBuilder.WALLS) as TileMapLayer).get_cell_source_id(tree) == -1, "벤 칸의 벽 타일이 사라짐 (그루터기만 남음)")
	check(world.level_map().is_wall(tree), "다시 들어오면 나무는 다시 자라 있음 (원본 맵은 그대로)")
	# 보스방 앞 탑
	var gate := _waystone("boss_gate")
	p.teleport(gate.global_position + Vector2(0, 10))
	await step(3)
	check(Story.waystones.has("boss_gate") and MapPanel.revealed_zones().has("golem_lair") and MapPanel.revealed_zones().has("forest"), "보스방 앞 탑 → 숲과 골렘 터까지 지도에 밝혀짐")
	check(StorySave.latest()["state"]["story"]["waystones"].has("boss_gate"), "보스방 앞에서 자동저장")


func _golem() -> Golem:
	for n in get_tree().get_nodes_in_group(Enemy.GROUP):
		if n is Golem:
			return n
	return null


func test_boss_room_rules() -> void:
	var p := _p()
	var lair := world.zone("golem_lair")
	var g := _golem()
	check(g != null and g.data == DB.enemies["golem_worn"] and g.mode == Golem.Mode.DORMANT, "지친 골렘이 있음 (아직 깨어나지 않음)")
	check(lair.rect.has_point(Vector2i((g.global_position / LevelMap.TILE_SIZE).floor())), "골렘은 골렘 터 안에 있음")
	check(not CombatState.is_restricted(get_tree()), "골렘 터 밖에서는 제한 없음")
	# 걸어서 들어간다 (서쪽 입구, 골렘이 깨지 않을 만큼 먼 자리)
	p.teleport(LevelMap.cell_center(lair.rect.position + Vector2i(-2, 11)))
	await step(2)
	input.push(Vector2.RIGHT, 50)
	await step(51)
	check(_zone() == "golem_lair" and lair.is_restricted(), "걸어서 골렘 터(보스방)로 들어감")
	check(g.mode == Golem.Mode.DORMANT and not CombatState.in_combat(get_tree()) and CombatState.is_restricted(get_tree()), "골렘이 깨기 전에도 보스방 안은 제한 구역")
	var before := int(StorySave.latest()["seq"])
	check(not main.saves.save_manual() and not main.saves.save_auto("timer") and int(StorySave.latest()["seq"]) == before, "보스방에서는 수동·자동 저장 모두 불가")
	check(not main.teleport("village"), "보스방에서는 순간이동 불가")
	check((_props(AreaExit)[0] as AreaExit).is_locked(), "3지역으로 가는 길은 아직 잠겨 있음")


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
	var drop: ItemPickup = null
	for n in _props(ItemPickup):
		if (n as ItemPickup).item_id == "golem_record":
			drop = n
	check(drop != null, "골렘 몸에서 자료가 떨어짐")
	check(not Story.inventory.has("golem_record") and not _stories.has("read:golem_record"), "전투 중에는 진실이 드러나지 않음 (자료를 읽기 전)")
	Debug.god_mode = false


func test_document_and_ending() -> void:
	var p := _p()
	var drop: ItemPickup = null
	for n in _props(ItemPickup):
		if (n as ItemPickup).item_id == "golem_record":
			drop = n
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
	main.inventory_panel.open()
	check(main.inventory_panel.ids(InventoryPanel.KIND_BAG).has("golem_record"), "골렘이 떨어뜨린 자료는 인벤토리에서 다시 읽을 수 있는 문서 아이템")
	main.inventory_panel.close()
	check(main.saves.save_manual() and StorySave.latest()["state"]["place"] == "골렘 터", "쓰러뜨린 뒤에는 보스방에서도 저장 가능")
	main.load_save(StorySave.latest())
	_scripted()
	await step(3)
	var g := _golem()
	check(g != null and g.mode == Golem.Mode.WRECK and not CombatState.in_combat(get_tree()), "불러와도 골렘은 잔해로 남아 있음")
	var again := false
	for n in _props(ItemPickup):
		if (n as ItemPickup).item_id == "golem_record":
			again = true
	check(not again, "이미 주운 자료는 다시 떨어져 있지 않음")
	var road: AreaExit = _props(AreaExit)[0]
	check(not road.is_locked(), "자료를 읽으면 3지역으로 가는 길이 열림")
	_p().teleport(road.global_position)
	await step(3)
	check(main.run == null and main._notice_layer.visible and main._notice.text.contains("3지역"), "3지역으로 가는 길 입구 = 이번 범위의 끝")
	await wait_until(func() -> bool: return main.title.is_showing(), int(DB.story.end_seconds * 60.0) + 30)
	check(main.title.is_showing() and main.title.can_continue, "끝 글 뒤 타이틀로 (이어하기 가능)")
