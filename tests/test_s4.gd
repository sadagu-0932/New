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
	check(DB.area("prologue") != null and world != null and DB.areas.size() == 2, "지역 파일은 프롤로그와 바깥 세상 둘뿐 (세상은 한 장)")
	var m := world.level_map()
	check(m.width == m.height and m.width >= 120, "세상은 넓은 정사각형 (%d×%d칸)" % [m.width, m.height])
	check(world.groups().size() == 10 and world.zones.size() >= 40, "지역 묶음 10개, 그 안의 작은 지역 %d개" % world.zones.size())
	var per_group_ok := true
	for g: String in world.groups():
		if world.zones_in_group(g).size() < 3:
			per_group_ok = false
	check(per_group_ok, "묶음마다 작은 지역이 여럿")
	var named: Array[String] = []
	for z in world.zones:
		if not z.display_name.is_empty():
			named.append(z.id)
	var names := {}
	for z in world.zones:
		names[z.display_name] = true
	check(named.size() == world.zones.size() and names.size() == world.zones.size() and names.has("연구소") and names.has("마석 광산촌") and names.has("골렘 터"),
		"작은 지역마다 서로 다른 이름이 있음 (연구소·마석 광산촌·골렘 터 …)")
	# 지역은 네모가 아니다: 지역마다 칸을 세어, 그 칸들을 감싸는 네모보다 훨씬 적은지 본다
	var counts := {}
	var boxes := {}
	for y in m.height:
		for x in m.width:
			var z := world.zone_at(Vector2i(x, y))
			if z == null:
				continue
			counts[z.id] = int(counts.get(z.id, 0)) + 1
			var box: Rect2i = boxes.get(z.id, Rect2i(x, y, 1, 1))
			boxes[z.id] = box.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
	check(counts.size() == world.zones.size(), "모든 칸이 어느 한 지역에 들어 있고, 빈 지역이 없음 (%d)" % counts.size())
	var irregular := 0
	for id: String in counts:
		if float(counts[id]) < float((boxes[id] as Rect2i).get_area()) * 0.9:
			irregular += 1
	check(irregular >= world.zones.size() * 3 / 4, "지역 모양이 네모로 딱 떨어지지 않음 (구불구불한 지역 %d개)" % irregular)
	# 연구소는 한가운데
	var lab_pos := world.landmark("lab_pos")
	var lab_center := Vector2(lab_pos) + Vector2(world.landmark("lab_size")) * 0.5
	check(lab_center.distance_to(Vector2(m.width, m.height) * 0.5) < 4.0 and world.zone_at(m.spawn_cell).id == "lab", "출발하는 연구소가 세상 한가운데")
	check(world.zone("lab").revealed_at_start and not world.zone("village").revealed_at_start, "연구소 지역만 처음부터 지도에 밝혀져 있음")
	check(world.prop_cells("E").size() == world.exits.size() and world.prop_cells("Y").size() == world.waystones.size()
		and world.prop_cells("$").size() == world.pickups.size() and world.prop_cells("N").size() == world.npcs.size()
		and world.prop_cells("I").size() == world.signs.size(), "맵의 소품 수 = 지역 데이터 수")
	check(world.exits.is_empty(), "화면이 바뀌는 출입구는 없음 (골렘까지 잡으면 TO BE CONTINUED)")
	# 골렘 이야기는 전부 연구소 가까이에 모여 있고, 나머지 넓은 땅은 다음 이야기용으로 남겨 둔다
	var lab_c := Vector2(world.landmark("lab_pos")) + Vector2(world.landmark("lab_size")) * 0.5
	var near := float(m.width) * 0.28
	check(Vector2(world.landmark("village_center")).distance_to(lab_c) < near and Vector2(world.landmark("lair_gate")).distance_to(lab_c) < near,
		"광산촌·골렘 터가 연구소 가까이에 (세상 한 변의 28%% 안, %.0f · %.0f칸)" % [Vector2(world.landmark("village_center")).distance_to(lab_c), Vector2(world.landmark("lair_gate")).distance_to(lab_c)])
	# 철길은 직각으로 꺾이지 않고 비스듬히(지그재그로) 이어진다: 가로·세로로 곧게 뻗은 구간이 짧다
	var rail: Array[Vector2i] = []
	for y in m.height:
		for x in m.width:
			if world.ground_at(Vector2i(x, y)) == "r":
				rail.append(Vector2i(x, y))
	var longest := 0
	for c in rail:
		var run := 0
		while world.ground_at(c + Vector2i(run + 1, 0)) == "r" and world.ground_at(c + Vector2i(run + 1, 1)) != "r" and world.ground_at(c + Vector2i(run + 1, -1)) != "r":
			run += 1
		longest = maxi(longest, run)
	check(longest < 14, "철길이 비스듬히 이어짐 (곧게 뻗은 가장 긴 구간 %d칸)" % longest)
	var sprites := {}
	for n in world.npcs:
		sprites[String(n.sprite)] = true
	check(sprites.size() == world.npcs.size() and sprites.has("npc_miner") and sprites.has("npc_child"), "주민마다 특징에 맞는 그림 %s" % [sprites.keys()])
	for name: String in sprites:
		check(DB.theme.load_sheet("story_props").has_animation(StringName(name)), "주민 그림 %s 있음" % name)
	# 길: 철길만 뚫려 있고, 쓰러진 나무 길은 나무를 베어야 한다
	var walk := _flood(m, false, false)
	check(walk.has(world.landmark("village_gate")), "연구소에서 철길을 따라 광산촌까지 걸어서 닿음")
	check(not _flood(m, false, true).has(world.landmark("village_gate")), "연구소 둘레는 숲으로 막혀 있고 철길이 유일하게 뚫린 길")
	check(walk.has(world.landmark("trail_before_block_0")) and not walk.has(world.landmark("trail_after_block_0")), "쓰러진 나무 길은 나무가 막고 있어 베어야 지나감")
	check(_flood(m, true, false).has(world.landmark("lair_gate")), "나무를 베면 골렘 터까지 닿음")
	var rail_cells := 0
	var trail_cells := 0
	for y in m.height:
		for x in m.width:
			var g := world.ground_at(Vector2i(x, y))
			rail_cells += 1 if g == "r" else 0
			trail_cells += 1 if g == "t" else 0
	check(rail_cells > 20 and world.ground_at(world.landmark("rail_mid")) == "r", "연구소와 광산촌은 철길로 이어짐 (%d칸)" % rail_cells)
	check(trail_cells > 60, "광산촌에서 골렘 터까지 쓰러진 나무 길 (%d칸)" % trail_cells)
	check(world.boss_room_rect.has_point(world.prop_cells("Z")[0]) and world.zone_at(world.prop_cells("Z")[0]).id == "golem_lair" and world.zone("golem_lair").group == "golem", "골렘은 쓰러진 숲 묶음의 골렘 터 안에")
	var ways: Array[String] = []
	for w in world.waystones:
		ways.append(w.id)
	ways.sort()
	check(ways.size() == 10 and ways.has("lab_exit") and ways.has("village") and ways.has("boss_gate"), "지역마다 지도를 여는 탑이 하나씩 (10개) %s" % [ways])
	var tower_zones := {}
	var tower_cells := world.prop_cells("Y")
	for cell in tower_cells:
		tower_zones[world.zone_at(cell).group] = true
	check(tower_zones.size() == 10, "탑은 묶음마다 하나씩 흩어져 있음")
	# 땅 모습이 여러 가지: 숲·물·바위·흙길이 다 있다
	var kinds := {}
	var water := 0
	var open_land := 0
	for y in m.height:
		for x in m.width:
			kinds[world.ground_at(Vector2i(x, y))] = true
			water += 1 if m.is_pit(Vector2i(x, y)) else 0
			open_land += 1 if m.is_floor(Vector2i(x, y)) else 0
	check(kinds.has("w") and kinds.has("m") and kinds.has("p") and kinds.has("g"), "지형이 섞여 있음: 숲·물·바위·흙길 %s" % [kinds.keys()])
	check(water > 300 and float(open_land) / float(m.width * m.height) > 0.35, "호수가 있고, 온통 숲이 아니라 트인 땅이 넓음 (물 %d칸, 트인 땅 %d%%)" % [water, open_land * 100 / (m.width * m.height)])
	# 마을은 작고 둥그스름하다: 흙바닥이 네모를 꽉 채우지 않는다
	var dirt := 0
	var dirt_box := Rect2i(world.landmark("village_center"), Vector2i.ONE)
	for y in m.height:
		for x in m.width:
			if world.ground_at(Vector2i(x, y)) == "v":
				dirt += 1
				dirt_box = dirt_box.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
	var fill := float(dirt) / float(dirt_box.get_area())
	check(fill > 0.6 and fill < 0.9 and dirt_box.size.x < 40, "광산촌은 작고 둥그스름함 (가로 %d칸, 네모의 %d%% 를 채움)" % [dirt_box.size.x, int(fill * 100)])
	for id: String in world.pickups:
		check(DB.item(id) != null, "획득물 %s 는 있는 아이템" % id)
	check(world.signs.any(func(t: String) -> bool: return t.contains("근접") and t.contains("벨 수")), "쓰러진 나무 길에서 나무를 벨 수 있다는 것을 알려줌 (표지판)")
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
	var enemy_in_village := false
	var vil := Rect2i(world.landmark("village_pos"), world.landmark("village_size"))
	for entry: Dictionary in m.props:
		if not Level.SPAWNS.has(entry["char"]):
			only_known = false
		if "CcSBZ".contains(entry["char"]) and vil.has_point(entry["cell"]):
			enemy_in_village = true
	check(only_known, "맵은 기존 적 글자(C c S B Z)와 스토리 소품만 사용 (새 적 없음)")
	check(not enemy_in_village and world.npcs.size() >= 3, "광산촌: 주민 있고 적 없음")
	for name: String in world.tilesets():
		check(DB.theme.load_json(name).has("tiles"), "타일 그림 %s" % name)
	for z in world.zones:
		for key: String in z.enemy_overrides.values():
			check(DB.enemies.has(key), "%s: 적 수치 %s 있음" % [z.id, key])
	var forest_charger := DB.enemies["charger_forest"] as EnemyData
	check(forest_charger.get_script() == (DB.enemies["charger"] as EnemyData).get_script() and forest_charger.max_hp != (DB.enemies["charger"] as EnemyData).max_hp,
		"지역별 적 차이는 같은 종류의 수치(data)로만")


## 시작점에서 걸어서 닿는 칸들. chop = 나무(벨 수 있는 벽)를 지나갈 수 있다고 치는지, no_rail = 철길을 막았다고 치는지
func _flood(m: LevelMap, chop: bool, no_rail: bool) -> Dictionary:
	var seen := {m.spawn_cell: true}
	var queue: Array[Vector2i] = [m.spawn_cell]
	var blocked := "RNY~"
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n := c + d
			if seen.has(n) or n.x < 1 or n.y < 1 or n.x >= m.width - 1 or n.y >= m.height - 1:
				continue
			var ch := m.char_at(n)
			if blocked.contains(ch) or (ch == "#" and not (chop and world.breakable_at(n))) or (no_rail and world.ground_at(n) == "r"):
				continue
			seen[n] = true
			queue.append(n)
	return seen


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


func _mark(mark: String, offset: Vector2i = Vector2i.ZERO) -> Vector2:
	return LevelMap.cell_center(world.landmark(mark) + offset)


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
		kinds[layer.get_cell_source_id(world.level_map().spawn_cell)] = true
		kinds[layer.get_cell_source_id(world.landmark("village_center"))] = true
		kinds[layer.get_cell_source_id(Vector2i(1, 1))] = true
		kinds[layer.get_cell_source_id(world.landmark("rail_mid"))] = true
		kinds[layer.get_cell_source_id(world.landmark("trail_before_block_0"))] = true
	kinds.erase(-1)
	check(kinds.size() == 5, "한 맵 안에서 땅마다 타일 그림이 다름 (연구소·마을·숲·철길·쓰러진 나무 길)")
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
	var m := world.level_map()
	check(MapPanel.reveal_circles().size() == 1, "처음엔 연구소 둘레의 원 하나만 밝혀져 있음")
	check(MapPanel.is_revealed(m.spawn_cell) and MapPanel.is_revealed(world.landmark("lab_gate"))
		and not MapPanel.is_revealed(world.landmark("village_center")) and not MapPanel.is_revealed(Vector2i(3, 3)),
		"연구소 둘레까지 밝혀지고 마을·먼 땅은 안개")
	# 원: 가운데는 다 밝혀지고 가장자리로 갈수록 점점 흐려진다
	var c0: Vector3 = MapPanel.reveal_circles()[0]
	var center := Vector2(c0.x, c0.y)
	var fade := DB.story.map_reveal_fade
	check(MapPanel.fog_at(center, MapPanel.reveal_circles()) == 0.0 and MapPanel.fog_at(center + Vector2(c0.z + 1.0, 0), MapPanel.reveal_circles()) == 1.0, "원 안은 밝고 원 밖은 안개")
	var mid := MapPanel.fog_at(center + Vector2(c0.z - fade * 0.5, 0), MapPanel.reveal_circles())
	check(mid > 0.2 and mid < 0.8, "원 가장자리는 점점 흐려짐 (%.2f)" % mid)
	var same := absf(MapPanel.fog_at(center + Vector2(c0.z - 3.0, 0), MapPanel.reveal_circles()) - MapPanel.fog_at(center + Vector2(0, c0.z - 3.0), MapPanel.reveal_circles())) < 0.001
	check(same, "완전한 원 (어느 쪽이든 같은 거리에서 같은 진하기)")
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
	# 연구소의 부서진 벽에서 철길을 따라 걸어 나간다: 화면이 바뀌지 않는다
	var p := _p()
	var lv := _lv()
	var gate := world.landmark("lab_gate")
	check(lv.map.is_floor(gate + Vector2i.LEFT) and world.ground_at(gate) == "r", "연구소 동쪽 벽이 뚫려 있고 그 앞에서 철길이 시작됨")
	p.teleport(_mark("lab_gate", Vector2i(-2, 0)))
	await step(2)
	check(_zone() == "lab", "아직 연구소")
	input.push(Vector2.RIGHT, 80)
	await step(81)
	check(p.global_position.x > _mark("lab_gate").x + 30.0 and _lv() == lv and p == _p(), "걸어서 벽 밖 철길로 — 같은 화면 그대로 (레벨·플레이어가 바뀌지 않음)")
	p.health.current = 3
	_toasts.clear()
	_stories.clear()
	p.teleport(_mark("rail_mid"))
	await step(2)
	p.teleport(_mark("village_gate", Vector2i(-1, 0)))
	await step(2)
	input.push(Vector2.RIGHT, 80)
	await step(81)
	check(_zone() == "village" and _lv() == lv, "철길 끝에서 걸어서 광산촌으로 (화면 전환 없음)")
	check(_toasts.has("마석 광산촌") and _stories.has("village_enter"), "지역에 들어서면 이름이 뜨고, 처음이면 글이 흘러감")
	check(p.health.current == 3 and Story.area == "world", "체력 그대로, 같은 세상")


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
	_p().teleport(stone.global_position + Vector2(0, 10))
	await step(3)
	check(Story.waystones.has("village") and MapPanel.reveal_circles().size() == Story.waystones.size() + 1 and MapPanel.is_revealed(world.landmark("village_center"))
		and MapPanel.revealed_zones().has("village"), "광산촌 탑 → 그 둘레가 둥글게 밝혀짐")
	check(MapPanel.is_revealed(world.landmark("trail_start")), "마을 둘레 숲(길 들머리)까지 밝혀짐")
	# 이웃한 원은 겹쳐서 이어진다: 연구소 원과 광산촌 원 사이 철길 가운데도 밝혀짐
	check(MapPanel.is_revealed(world.landmark("rail_mid")), "연구소 원과 광산촌 원이 자연스럽게 이어짐 (철길 가운데도 밝혀짐)")
	check(panel.open() and get_tree().paused, "지도 열기 (게임 일시정지)")
	check(panel.targets.size() == 2, "순간이동할 수 있는 곳 = 켠 탑 2곳")
	check(MapPanel.zone_label(world.zone("lab")) == "연구소" and MapPanel.zone_label(world.zone("golem_lair")) == ""
		and MapPanel.zone_label(world.zones_in_group("highland")[0]) == "", "가려진 지역은 이름도 가려짐")
	check(panel._fog_old != null and panel._fog_fade > 0.9 and Story.has_flag("map_seen:village"), "새로 밝혀진 곳은 안개가 걷히는 것부터 보여줌")
	# 지명은 가리키는 곳 가까이에 있는 것만 뜬다. 열리지 않은 곳에는 아무 글자도 없다
	panel._use_mouse = false
	panel._fog_fade = 0.0
	var zoom_before: int = panel.zoom_index
	var camera_before: Vector2 = panel.camera
	panel.set_zoom(2)
	var lab_name_pos := MapPanel.world_pos(world.zone_center("lab"))
	panel.center_on(lab_name_pos)
	var near_names: Array = panel.labels_near_pointer().map(func(l: Dictionary) -> String: return l["text"])
	check(near_names.has("연구소"), "가리키는 곳 가까이의 지명이 뜸 %s" % [near_names])
	var far_zone := world.zones_in_group("village")[0]
	check(not near_names.has(far_zone.display_name) or MapPanel.world_pos(world.zone_center(far_zone.id)).distance_to(lab_name_pos) <= DB.story.map_label_radius_px, "먼 곳의 지명은 뜨지 않음")
	var fog_zone := world.zones_in_group("highland")[0]
	panel.center_on(MapPanel.world_pos(world.zone_center(fog_zone.id)))
	panel._refresh()
	check(panel.labels_near_pointer().is_empty() and panel._info.text == "", "아직 열리지 않은 곳에는 아무 글자도 띄우지 않음 (??? 없음)")
	panel.set_zoom(zoom_before)
	panel.camera = camera_before
	panel._fog_fade = 1.0
	for i in 90:
		await get_tree().process_frame
	check(panel._fog_fade < 0.05, "안개가 걷힘")
	var here := MapPanel.world_pos(_p().global_position / LevelMap.TILE_SIZE)
	check(Rect2(panel.camera, MapPanel.VIEW.size).grow(1.0).has_point(here), "지도를 열면 지금 있는 곳이 보임")
	# 휠: 크게/작게. 가장 작게 하면 세상 전체가 한눈에
	var start_zoom: int = panel.zoom_index
	panel.set_zoom(0)
	check(MapPanel.world_size().x <= MapPanel.VIEW.size.x + 0.5 and MapPanel.world_size().y <= MapPanel.VIEW.size.y + 0.5,
		"가장 작게 → 세상 전체가 지도 창 안에 (%.0f×%.0f px)" % [MapPanel.world_size().x, MapPanel.world_size().y])
	var whole := Rect2(panel.camera, MapPanel.VIEW.size).grow(1.0)
	check(whole.has_point(Vector2.ZERO) and whole.has_point(MapPanel.world_size()), "전체 보기에서는 세상의 양 끝이 다 보임")
	panel.set_zoom(99)
	check(panel.zoom_index == MapPanel.zoom_levels().size() - 1 and MapPanel.world_size().x > MapPanel.VIEW.size.x * 2.0, "가장 크게 (한 칸 %.0f px)" % MapPanel.tile_px())
	var anchor := Vector2(40, 30)
	var before_cell := panel.cell_at(anchor)
	panel.set_zoom(panel.zoom_index - 1, anchor)
	check((panel.cell_at(anchor) - before_cell).length() <= 1.5, "휠로 크기를 바꿔도 마우스가 가리키던 곳은 그 자리에")
	panel.set_zoom(start_zoom)
	# 끌어서 움직이기 (마우스)
	panel.center_on(MapPanel.world_size() * 0.5)
	var cam: Vector2 = panel.camera
	panel._dragging = true
	panel._drag_moved = 10.0
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(-20, -10)
	panel._input(drag)
	panel._dragging = false
	check(panel.camera.is_equal_approx(cam + Vector2(20, 10)), "지도를 끌면 따라 움직임")
	# 핀: 빈 곳을 누르면 작은 창 → 핀 꽂기
	var spot := world.landmark("camp_0")
	panel.click_cell(spot)
	check(panel.popup_open and panel.popup_options == ([MapPanel.OPT_PIN, MapPanel.OPT_CANCEL] as Array[String]), "빈 곳을 누르면 핀 꽂기 창")
	panel.choose(1)
	check(not panel.popup_open and Story.pins.is_empty(), "취소하면 아무 일 없음")
	panel.click_cell(spot)
	panel.choose(0)
	check(Story.pins == [[spot.x, spot.y]] and not panel.popup_open, "원하는 자리에 핀을 꽂음 (안개 속에도)")
	panel.click_cell(spot + Vector2i(1, 0))
	check(panel.popup_open and panel.popup_options[0] == MapPanel.OPT_UNPIN, "핀을 누르면 지우기 창")
	panel.choose(0)
	check(Story.pins.is_empty(), "핀 지우기")
	for i in DB.story.map_max_pins:
		Story.pins.append([10 + i * 8, 10])
	panel.click_cell(Vector2i(80, 140))
	check(not panel.popup_open and panel.current_notice() == DB.story.text_pins_full % DB.story.map_max_pins, "핀은 정해진 개수까지")
	Story.pins = [[spot.x, spot.y]]
	# 탑을 누르면 순간이동 창
	var lab_tower: Vector2i = Vector2i.ZERO
	for t in panel.targets:
		if (t["waystone"] as WaystoneData).id == "lab_exit":
			lab_tower = t["cell"]
	# 탑 표시는 작게 있다가, 가리키는 곳이 가까이 오면 커지며 활성화된다
	panel._use_mouse = false
	panel.center_on(MapPanel.world_pos(Vector2(lab_tower) + Vector2(40, 30)))
	panel._refresh()
	check(panel.hovered == -1, "멀리 있으면 탑 표시는 작은 채로")
	panel.center_on(MapPanel.world_pos(Vector2(lab_tower) + Vector2(0.5, 0.5)))
	panel._refresh()
	check(panel.hovered >= 0 and (panel.targets[panel.hovered]["waystone"] as WaystoneData).id == "lab_exit", "탑 그림 위에 올리면 그 탑이 커지며 활성화됨")
	# 탑 그림 바로 옆(몇 px 떨어진 곳)은 아니다: 거의 위에 올려야 한다
	var tower_px := MapPanel.world_pos(Vector2(lab_tower) + Vector2(0.5, 0.5)).round()
	panel.hovered = -1
	panel.center_on(tower_px + Vector2(6, 2))
	panel._refresh()
	check(panel.hovered == -1, "탑 그림에서 몇 px 떨어져 있으면 커지지 않음")
	panel.center_on(tower_px + Vector2(1, -3))
	panel._refresh()
	check(panel.hovered >= 0, "탑 그림 위에 올리면 커짐")
	panel.center_on(tower_px + Vector2(4, -10))
	panel._refresh()
	check(panel.hovered >= 0, "커진 뒤에는 커진 그림 안에 있는 동안 그대로 (떨리지 않게)")
	panel.center_on(tower_px + Vector2(4, -10))
	panel.hovered = -1
	panel._refresh()
	check(panel.hovered == -1, "커지기 전에는 그 자리(커진 그림 범위)로는 커지지 않음")
	panel.click_cell(lab_tower)
	check(panel.popup_open and panel.popup_options[0] == MapPanel.OPT_TELEPORT and panel._popup_title.text == "연구소 탑", "켠 탑을 누르면 순간이동 창 (%s)" % panel._popup_title.text)
	var hp := _p().health.current
	var lv := _lv()
	panel.choose(0)
	await step(3)
	check(not panel.is_open and not get_tree().paused and _zone() == "lab", "'여기로 순간이동' → 연구소 탑으로")
	check(_lv() == lv, "같은 세상 안의 순간이동은 화면을 다시 띄우지 않음")
	check(_p().global_position.distance_to(_waystone("lab_exit").global_position) <= LevelMap.TILE_SIZE * 1.5 and _p().health.current == hp, "탑 옆에 도착, 체력 그대로")
	# 핀은 저장된다
	var saved_pins: Array = []
	if main.saves.save_manual():
		saved_pins = StorySave.latest()["state"]["story"]["pins"]
	check(saved_pins.size() == 1 and int(saved_pins[0][0]) == spot.x and int(saved_pins[0][1]) == spot.y, "꽂은 핀은 저장에 들어감")
	# 전투 중에는 불가
	level = _lv()
	var e := spawn_enemy("charger_weak", _p().global_position + Vector2(40, 0))
	level = null
	await wait_until(func() -> bool: return e.has_target, 30)
	panel.open()
	var village_tower: Vector2i = Vector2i.ZERO
	for t in panel.targets:
		if (t["waystone"] as WaystoneData).id == "village":
			village_tower = t["cell"]
	panel.click_cell(village_tower)
	panel.choose(0)
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
	main.load_save(StorySave.latest())
	_scripted()
	await step(3)
	var p := _p()
	var lv := _lv()
	var kinds := {}
	var only_three := true
	var charger: Enemy = null
	for n in get_tree().get_nodes_in_group(Enemy.GROUP):
		var e := n as Enemy
		var z := world.zone_at_pos(e.global_position)
		if e is Golem or z == null or z.group != "golem":
			continue
		kinds[(e.get_script() as Script).get_global_name()] = true
		if not (e is Charger or e is Shooter or e is Spreader):
			only_three = false
		if e is Charger:
			charger = e
	check(only_three and kinds.size() == 3, "쓰러진 숲의 적은 기존 3종의 조합 %s (불러오면 적이 다시 나옴)" % [kinds.keys()])
	check(charger != null and charger.data == DB.enemies["charger_forest"], "쓰러진 숲의 돌진형은 숲용 수치를 씀")
	Debug.god_mode = true
	_kill_enemies()
	await step(2)
	# 쓰러진 나무 길: 표지판이 나무를 벨 수 있다고 알려주고, 길을 막은 나무를 근접으로 벤다
	p.teleport(_mark("trail_before_block_0", Vector2i(0, 0)))
	await step(3)
	var sign_shown := false
	for n in _props(Signpost):
		if (n as Signpost).is_showing() and (n as Signpost).text.contains("벨 수"):
			sign_shown = true
	check(sign_shown, "막힌 곳 앞 표지판: 근접 공격으로 나무를 벨 수 있다")
	# 막힌 나무와 그 앞에 설 자리 (세상 생성기가 적어 둔 지점)
	var tree := world.landmark("trail_block_tree_0")
	var dir := tree - world.landmark("trail_block_stand_0")
	check(lv.map.is_wall(tree) and lv.breakable.can_break(tree), "길을 막은 나무는 벨 수 있음")
	check(not lv.breakable.can_break(Vector2i(0, 5)), "세상 맨 바깥 테두리는 못 벰")
	var lab_wall := world.landmark("lab_pos")
	var house := Vector2i(-1, -1)
	var vr := Rect2i(world.landmark("village_pos"), world.landmark("village_size"))
	for y in range(vr.position.y, vr.end.y):
		for x in range(vr.position.x, vr.end.x):
			if house.x < 0 and lv.map.is_wall(Vector2i(x, y)) and world.ground_at(Vector2i(x, y)) == "v":
				house = Vector2i(x, y)
	check(lv.map.is_wall(lab_wall) and not lv.breakable.can_break(lab_wall) and house.x >= 0 and not lv.breakable.can_break(house), "연구소 벽과 마을 집은 벨 수 없음")
	var far_tree := Vector2i(-1, -1)
	var rock := Vector2i(-1, -1)
	for y in range(4, lv.map.height - 4):
		for x in range(4, lv.map.width - 4):
			var c := Vector2i(x, y)
			if not lv.map.is_wall(c):
				continue
			if rock.x < 0 and world.ground_at(c) == "m":
				rock = c
			if far_tree.x < 0 and world.ground_at(c) == "g" and not ["lab", "village", "golem"].has(world.zone_at(c).group):
				far_tree = c
	check(far_tree.x >= 0 and lv.breakable.can_break(far_tree), "먼 땅의 나무도 어디서든 벨 수 있음")
	check(rock.x >= 0 and not lv.breakable.can_break(rock), "바위는 벨 수 없음")
	var stand := tree - dir
	p.teleport(LevelMap.cell_center(stand))
	await step(2)
	input.push(Vector2(dir), 30)
	await step(31)
	check(p.global_position.distance_to(LevelMap.cell_center(tree)) > 8.0, "베기 전에는 나무에 막힘")
	var wood := Story.inventory.count("wood")
	var swings := 0
	while lv.map.is_wall(tree) and swings < 6:
		p.teleport(LevelMap.cell_center(stand))
		input.push(Vector2.ZERO, 1, 0, InputFrame.MELEE, LevelMap.cell_center(tree))
		await step(p.weapon.melee.active_ticks + p.weapon.melee.recovery_ticks + 3)
		swings += 1
	check(not lv.map.is_wall(tree) and swings == world.break_hits, "근접으로 %d번 치면 나무가 베어짐" % swings)
	check(Story.inventory.count("wood") > wood, "벤 나무에서 나무토막을 얻음")
	# 나무를 베면 탄약도 채워진다
	p.ammo.set_current(0)
	var tree2 := tree + Vector2i(0, -1)
	while not (lv.map.is_wall(tree2) and lv.breakable.can_break(tree2)) and tree2.y > tree.y - 6:
		tree2 += Vector2i(0, -1)
	if lv.breakable.can_break(tree2):
		for i in world.break_hits:
			lv.breakable.hit(tree2)
	check(p.ammo.current == world.break_ammo, "나무를 베면 탄약이 %d발 채워짐 (%d)" % [world.break_ammo, p.ammo.current])
	# 전투 중이 아니면 일정 시간마다 재장전
	p.ammo.set_current(0)
	var director: AreaDirector = lv.area_director
	director.reload_ticks = 3
	await step(5)
	check(p.ammo.current == p.ammo.maximum, "전투 중이 아니면 %d초마다 재장전" % int(DB.story.auto_reload_seconds))
	check(director.reload_ticks > int(DB.story.auto_reload_seconds * 60.0) - 10, "재장전 뒤 다시 처음부터 셈")
	p.teleport(LevelMap.cell_center(stand))
	input.push(Vector2(dir), 20, 0, 0, LevelMap.cell_center(tree))
	await step(21)
	check(p.global_position.distance_to(LevelMap.cell_center(tree)) < 8.0 or Vector2(p.global_position - LevelMap.cell_center(stand)).dot(Vector2(dir)) > 12.0, "벤 자리로 지나갈 수 있음")
	check((lv.tiles.get_node(LevelBuilder.WALLS) as TileMapLayer).get_cell_source_id(tree) == -1, "벤 칸의 벽 타일이 사라짐 (그루터기만 남음)")
	check(world.level_map().is_wall(tree), "불러오면 나무는 다시 자라 있음 (원본 맵은 그대로)")
	# 골렘 터 앞 탑
	var gate := _waystone("boss_gate")
	p.teleport(gate.global_position + Vector2(0, 10))
	await step(3)
	check(Story.waystones.has("boss_gate") and MapPanel.is_revealed(world.landmark("lair_gate")) and MapPanel.revealed_zones().has("golem_lair"), "골렘 터 앞 탑 → 골렘 터 둘레가 지도에 밝혀짐")
	check(StorySave.latest()["state"]["story"]["waystones"].has("boss_gate"), "골렘 터 앞에서 자동저장")


func _golem() -> Golem:
	for n in get_tree().get_nodes_in_group(Enemy.GROUP):
		if n is Golem:
			return n
	return null


func test_boss_room_rules() -> void:
	var p := _p()
	var lair := world.boss_room_rect
	var g := _golem()
	check(g != null and g.data == DB.enemies["golem_return"] and g.mode == Golem.Mode.DORMANT, "다시 만나는 골렘이 있음 (아직 깨어나지 않음)")
	check(lair.has_point(Vector2i((g.global_position / LevelMap.TILE_SIZE).floor())), "골렘은 골렘 터 안에 있음")
	check(not CombatState.is_restricted(get_tree()), "골렘 터 밖에서는 제한 없음")
	# 걸어서 들어간다 (서쪽 입구, 골렘이 깨지 않을 만큼 먼 자리)
	p.teleport(_mark("lair_gate", Vector2i(-1, 0)))
	await step(2)
	input.push(Vector2.RIGHT, 50)
	await step(51)
	check(lair.has_point(Vector2i((p.global_position / LevelMap.TILE_SIZE).floor())) and world.in_boss_room(p.global_position), "걸어서 골렘 터(보스방)로 들어감")
	check(g.mode == Golem.Mode.DORMANT and not CombatState.in_combat(get_tree()) and CombatState.is_restricted(get_tree()), "골렘이 깨기 전에도 보스방 안은 제한 구역")
	var before := int(StorySave.latest()["seq"])
	check(not main.saves.save_manual() and not main.saves.save_auto("timer") and int(StorySave.latest()["seq"]) == before, "보스방에서는 수동·자동 저장 모두 불가")
	check(not main.teleport("village"), "보스방에서는 순간이동 불가")


func test_golem_phase2() -> void:
	var g := _golem()
	var d := g.gd()
	var prologue := DB.enemies["golem"] as GolemData
	var p := _p()
	Debug.god_mode = true
	p.teleport(g.global_position + Vector2(0, 70))
	await step(2)
	check(g.mode == Golem.Mode.INTRO and CombatState.in_combat(get_tree()), "가까이 가면 깨어남")
	await wait_until(func() -> bool: return g.mode == Golem.Mode.FIGHT, d.intro_ticks + 5)
	check(g.phase is GolemPhase1 and not (g.phase is GolemPhase2), "프롤로그에서 봤던 1페이즈부터")
	check((g.phase as GolemPhase1).speed_mult > 1.0 and d.phase1_speed_mult > prologue.phase1_speed_mult, "1페이즈가 프롤로그보다 빠름 (×%.2f)" % (g.phase as GolemPhase1).speed_mult)
	check(d.ring_bullets > prologue.ring_bullets and d.groggy_perfect_hits > prologue.groggy_perfect_hits, "탄이 더 많고 그로기도 더 어렵다")
	# 1페이즈를 깨면 컷씬 없이 다시 일어나 2페이즈로
	g.hp = 1
	g.hurtbox.receive_hit(HitInfo.make(DB.parry.reflect_damage, HitInfo.Kind.REFLECT, Team.PLAYER, Vector2.RIGHT, null))
	check(g.mode == Golem.Mode.INTRO and not g.defeated and g.hp == d.max_hp and _props(GolemCutscene).is_empty(), "1페이즈 격파 → 컷씬 없이 다시 일어남 (체력 다시 참)")
	check(Game.is_story_mode() and not Story.has_flag("golem_destroyed"), "아직 쓰러진 것이 아님")
	await wait_until(func() -> bool: return g.mode == Golem.Mode.FIGHT, d.phase2_transition_ticks + 5)
	check(g.phase is GolemPhase2 and g.phase.number() == 2, "이어서 2페이즈 (기존 페이즈 상태 구조)")
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
	# 자료를 읽고 나면 글이 흘러간 뒤 TO BE CONTINUED → 타이틀
	main._ending_left = 0.0
	main._on_document_read("golem_record")
	check(main._ending_left > 0.0 and main.run != null, "자료를 읽으면 잠시 뒤 끝이 남 (그동안 게임은 계속)")
	await wait_until(func() -> bool: return main._notice_layer.visible, int(DB.story.ending_delay_seconds * 60.0) + 30)
	check(main.run == null and main._notice_layer.visible and main._notice.text == "TO BE CONTINUED", "골렘까지 잡고 자료를 읽으면 TO BE CONTINUED")
	await wait_until(func() -> bool: return main.title.is_showing(), int(DB.story.end_seconds * 60.0) + 30)
	check(main.title.is_showing() and main.title.can_continue, "끝 글 뒤 타이틀로 (이어하기 가능)")
