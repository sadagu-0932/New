extends TestBase
## S3: 인벤토리 — 아이템 데이터, 무기 통합(원거리 무기로 근접), 갑옷 스탯 수정, 소모품, 자료, 스킬 2칸, 인벤토리 화면.

var main: Node
var _skills_used: Array[String] = []


func run_all() -> void:
	print("\n[S3] 인벤토리·아이템·무기 통합")
	StorySave.clear_all()
	Events.skill_used.connect(func(id: String) -> void: _skills_used.append(id))
	test_item_data()
	test_stat_math()
	await _boot()
	await test_start_inventory()
	await test_weapon_swap()
	await test_armor()
	await test_consumables()
	await test_skills()
	await test_combat_lock()
	await test_panel()
	await test_save_roundtrip()
	main.queue_free()
	PlayerInput.source = ScriptedInputSource.new()
	await step(2)
	await test_speedrun_rules_unchanged()
	StorySave.clear_all()


func _count_tres(path: String) -> int:
	var n := 0
	var dir := DirAccess.open(path)
	for d in dir.get_directories():
		n += _count_tres("%s/%s" % [path, d])
	for f in dir.get_files():
		if f.trim_suffix(".remap").ends_with(".tres"):
			n += 1
	return n


func test_item_data() -> void:
	check(DB.items.size() == _count_tres(DB.ITEMS_DIR) and DB.items.size() > 0, "data/items 의 파일이 전부 자동 등록됨 (%d개, 코드 목록 없음)" % DB.items.size())
	var per_cat := {}
	var icons := DB.theme.load_sheet("items")
	var missing: Array[String] = []
	var forbidden := ["처형", "은신", "돌진 베기", "재패링", "콤보", "연속"]
	var bad: Array[String] = []
	for item in DB.items_sorted():
		per_cat[item.category] = int(per_cat.get(item.category, 0)) + 1
		if not icons.has_animation(item.icon):
			missing.append(item.id)
		for w: String in forbidden:
			if (item.display_name + item.description + item.document_text).contains(w):
				bad.append(item.id)
		if item.category == ItemData.Category.WEAPON:
			check(item.weapon != null and item.weapon.gun != null and item.weapon.melee != null and item.weapon.parry != null,
				"무기 %s: 사격·근접·패링 수치가 무기 데이터 안에 있음" % item.id)
	check(missing.is_empty(), "모든 아이템에 아이콘 있음 %s" % [missing])
	check(bad.is_empty(), "아이템 글에 숨은 테크 단어 없음 %s" % [bad])
	for cat in ItemData.Category.values():
		var n := int(per_cat.get(cat, 0))
		# 자료는 골렘이 떨어뜨리는 것(S7)이 더해진다
		check(n >= 1 and n <= 7, "분류 %s: 임시 아이템 %d개" % [DB.inventory.category_names[cat], n])
	var ordered := true
	var list := DB.items_sorted()
	for i in list.size() - 1:
		if list[i].category > list[i + 1].category:
			ordered = false
	check(ordered, "아이템 목록은 분류 순")


func test_stat_math() -> void:
	var a := StatMod.new()
	a.stat = "max_hp"
	a.op = StatMod.Op.ADD
	a.value = 2.0
	var b := StatMod.new()
	b.stat = "max_hp"
	b.op = StatMod.Op.MUL
	b.value = 0.5
	var item := ItemData.new()
	item.stat_mods = [a, b]
	check_near(Loadout.apply_mods("max_hp", 4.0, [item]), 3.0, 0.001, "스탯 수정: (기본 + 더하기) × 곱하기")
	check_near(Loadout.apply_mods("move_speed", 90.0, [item]), 90.0, 0.001, "다른 스탯에는 영향 없음")
	check(InventoryPanel.mod_text(a) == "최대 체력 +2" and InventoryPanel.mod_text(b) == "최대 체력 ×0.5", "스탯 수정 글: %s / %s" % [InventoryPanel.mod_text(a), InventoryPanel.mod_text(b)])


func _boot() -> void:
	if level != null:
		level.queue_free()
		level = null
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	await step(2)
	main.start_new_game()
	_scripted()
	await step(3)
	# 시작 아이템 확인이 끝나면 test_start_inventory 에서 나머지(맵에서 줍는 것)를 넣어 준다


func _scripted() -> void:
	input = ScriptedInputSource.new()
	PlayerInput.source = input


func _p() -> Player:
	return main.run.level.player


func test_start_inventory() -> void:
	var inv := Story.inventory
	check(inv.weapon_id == "lab_gun" and inv.armor_id("armor") == "lab_suit" and inv.armor_id("helmet") == "" and inv.armor_id("pants") == "", "시작 장착: 시험용 마석총 + 실험체 도포")
	check(inv.owned_skills.size() == 5, "스킬 5종을 처음부터 전부 보유")
	check(inv.skill_ids[0] == DB.game_config.default_skill_id and _p().skill.data.id == inv.skill_ids[0], "Q 에는 기본 스킬")
	check(not inv.skill2_unlocked() and _p().skill2 == null, "스킬2(F) 칸은 프롤로그가 끝나기 전엔 잠김")
	var p := _p()
	check(p.weapon.gun == DB.gun and p.weapon.melee == DB.melee and p.weapon.parry == DB.parry, "시작 무기 수치 = 기존 수치 (data/gun·melee·parry.tres)")
	check(p.ammo.maximum == DB.gun.magazine_size and p.health.maximum == DB.player.max_hp, "탄창·체력 기본값")
	check(not inv.has("heavy_gun") and not inv.has("plated_coat") and not inv.has("golem_record"), "다른 무기·갑옷·자료는 처음엔 없음 (맵에서 얻는다)")
	for id: String in ["heavy_gun", "rapid_gun", "plated_coat", "light_wrap", "lab_memo"]:
		inv.add(id)
	inv.add("mana_shard", 3)


func test_weapon_swap() -> void:
	var inv := Story.inventory
	var p := _p()
	var heavy := DB.item("heavy_gun")
	check(inv.equip("heavy_gun") and inv.weapon_id == "heavy_gun", "무기 교체")
	check(p.weapon == heavy.weapon and p.gun.data == heavy.weapon.gun, "플레이어가 장착 무기의 사격 수치를 씀")
	check(p.ammo.maximum == heavy.weapon.gun.magazine_size and p.ammo.current <= p.ammo.maximum, "탄창 크기가 무기를 따라감 (%d/%d)" % [p.ammo.current, p.ammo.maximum])
	check(p.melee.data == heavy.weapon.melee and p.melee.parry == heavy.weapon.parry, "근접·패링 수치도 같은 무기에서 옴 (별도 근접 무기 없음)")
	check(is_equal_approx((p.melee.hitbox.shape_node.shape as CircleShape2D).radius, heavy.weapon.melee.radius), "근접 판정 범위가 무기를 따라감")
	check(not inv.equip("heavy_gun"), "같은 무기를 다시 고르면 변화 없음 (무기는 벗을 수 없음)")
	# 실제로 쏴 보면 그 무기의 탄
	Debug.god_mode = true
	p.ammo.set_current(p.ammo.maximum)
	var aim := p.global_position + Vector2(100, 0)
	input.push(Vector2.ZERO, 2, InputFrame.SHOOT, InputFrame.SHOOT, aim)
	await step(3)
	var found := false
	for n in get_tree().get_nodes_in_group(Level.GROUP_PROJECTILES)[0].get_children():
		if n is Projectile and (n as Projectile).team == Team.PLAYER and (n as Projectile).damage == heavy.weapon.gun.projectile.damage:
			found = true
	check(found, "쏜 탄의 데미지 = 장착 무기의 탄 데미지 (%d)" % heavy.weapon.gun.projectile.damage)
	# 근접: 총으로 후려치기 (총 그림이 휘둘러진다)
	input.push(Vector2.ZERO, 1, 0, InputFrame.MELEE, aim)
	await step(3)
	check(p.melee.is_active() and p._gun.visible, "근접 중 총이 보임 (총으로 후려치는 동작)")
	await step(heavy.weapon.melee.active_ticks + heavy.weapon.melee.recovery_ticks + 2)
	Debug.god_mode = false
	inv.equip("lab_gun")
	check(p.weapon.gun == DB.gun and p.ammo.maximum == DB.gun.magazine_size, "원래 무기로 되돌림")


func test_armor() -> void:
	var inv := Story.inventory
	var p := _p()
	var base_hp := DB.player.max_hp
	check(inv.equip("plated_coat"), "갑옷 장착")
	check(p.health.maximum == base_hp + 1, "덧댄 철판 외투: 최대 체력 +1 (%d)" % p.health.maximum)
	check_near(p._move_speed, DB.player.move_speed * 0.9, 0.01, "덧댄 철판 외투: 이동 속도 ×0.9")
	p.health.current = p.health.maximum
	inv.equip("light_wrap")
	check(p.health.maximum == base_hp - 1 and p.health.current == base_hp - 1, "가벼운 감개옷: 최대 체력 -1, 넘치는 체력은 깎임")
	check_near(p._move_speed, DB.player.move_speed * 1.1, 0.01, "가벼운 감개옷: 이동 속도 ×1.1")
	# 투구·바지는 갑옷과 다른 칸이라 함께 입는다
	inv.add("miner_cap")
	inv.add("work_pants")
	inv.add("sight_band")
	check(inv.equip("miner_cap") and inv.equip("work_pants") and inv.armor_id("armor") == "light_wrap", "투구·바지를 입어도 갑옷은 그대로 (칸이 따로)")
	check(inv.equipped_armors().size() == 3, "투구 + 갑옷 + 바지 세 가지를 함께 장착")
	check_near(p._move_speed, DB.player.move_speed * 1.1 * 1.05, 0.01, "여러 칸의 효과가 함께 적용")
	check(p._hurt_invuln_ticks == DB.player.hurt_invuln_ticks + 20, "투구 효과: 피격 후 무적 +20틱")
	check(inv.equip("sight_band") and inv.armor_id("helmet") == "sight_band", "같은 칸의 다른 투구를 고르면 바꿔 낌")
	inv.equip("sight_band")
	inv.equip("work_pants")
	check(inv.armor_id("helmet") == "" and inv.armor_id("pants") == "", "입은 것을 다시 고르면 벗음")
	check(inv.equip("light_wrap") and inv.armor_id("armor") == "", "입은 갑옷을 다시 고르면 벗음")
	check(p.health.maximum == base_hp and is_equal_approx(p._move_speed, DB.player.move_speed), "벗으면 기본 수치")
	inv.equip("lab_suit")


func test_consumables() -> void:
	var inv := Story.inventory
	var p := _p()
	p.health.current = p.health.maximum
	var n := inv.count("heal_vial")
	check(not inv.use("heal_vial", p) and inv.count("heal_vial") == n, "체력이 가득이면 약병을 쓰지 않음 (안 줄어듦)")
	p.health.current = 1
	check(inv.use("heal_vial", p) and p.health.current == 3 and inv.count("heal_vial") == n - 1, "회복 약병: 체력 +2, 하나 줄어듦")
	p.ammo.set_current(0)
	check(inv.use("ammo_cell", p) and p.ammo.current == p.ammo.maximum and not inv.has("ammo_cell"), "마석 탄창: 탄약 채움, 다 쓰면 목록에서 사라짐")
	check(not inv.use("mana_shard", p) and not inv.use("lab_memo", p), "재료·자료는 '사용'되지 않음")
	inv.add("heal_vial", 2)
	check(inv.count("heal_vial") == n + 1, "아이템 획득")
	inv.add("no_such_item")
	check(not inv.has("no_such_item"), "없는 아이템 id 는 무시")
	p.health.current = p.health.maximum


func test_skills() -> void:
	var inv := Story.inventory
	var p := _p()
	check(inv.set_skill(Inventory.SLOT_Q, "blink") and p.skill.data.id == "blink", "Q 스킬 지정 → 플레이어에 반영")
	check(not inv.set_skill(Inventory.SLOT_F, "mark") and p.skill2 == null, "잠긴 스킬2 칸에는 지정 불가")
	Story.set_flag(DB.inventory.skill2_unlock_flag)
	check(inv.skill2_unlocked(), "프롤로그가 끝나면 스킬2 칸이 열림")
	check(inv.set_skill(Inventory.SLOT_F, "mark") and p.skill2 != null and p.skill2.data.id == "mark", "F 스킬 지정 → 플레이어에 반영")
	check(inv.set_skill(Inventory.SLOT_Q, "mark") and inv.skill_ids == (["mark", "blink"] as Array[String]), "다른 칸의 스킬을 고르면 서로 맞바꿈 %s" % [inv.skill_ids])
	check(p.skill.data.id == "mark" and p.skill2.data.id == "blink", "맞바꾼 결과가 플레이어에 반영")
	inv.set_skill(Inventory.SLOT_Q, "shockwave")
	inv.set_skill(Inventory.SLOT_F, "absorb")
	_skills_used.clear()
	input.push(Vector2.ZERO, 1, 0, InputFrame.SKILL2)
	await step(3)
	check(_skills_used == (["absorb"] as Array[String]), "F 를 누르면 스킬2 발동 %s" % [_skills_used])
	input.push(Vector2.ZERO, 1, 0, InputFrame.SKILL)
	await step(3)
	check(_skills_used.has("shockwave") and p.skill2.cooldown_left > 0 and p.skill.cooldown_left > 0, "Q·F 쿨타임은 따로")


func test_combat_lock() -> void:
	var inv := Story.inventory
	var p := _p()
	var panel: InventoryPanel = main.inventory_panel
	level = main.run.level
	var e := spawn_enemy("charger_weak", p.global_position + Vector2(40, 0))
	level = null
	Debug.god_mode = true
	await wait_until(func() -> bool: return e.has_target, 30)
	check(panel.open() and get_tree().paused, "전투 중에도 인벤토리는 열림 (게임 일시정지)")
	panel.select(InventoryPanel.KIND_BAG, "heavy_gun")
	panel.activate()
	check(inv.weapon_id == "lab_gun" and panel.current_notice() == DB.inventory.text_in_combat, "전투 중에는 장착 변경 불가 + 안내")
	panel.select(InventoryPanel.KIND_SKILL, "blink")
	panel.activate()
	check(inv.skill_ids[0] == "shockwave", "전투 중에는 스킬 지정 불가")
	p.health.current = 1
	panel.select(InventoryPanel.KIND_BAG, "heal_vial")
	panel.activate()
	check(p.health.current == 3, "전투 중에도 소모품은 사용 가능")
	panel.close()
	check(not get_tree().paused, "닫으면 다시 진행")
	e.dead = true
	e.queue_free()
	Debug.god_mode = false
	p.health.current = p.health.maximum
	await step(2)


func test_panel() -> void:
	var panel: InventoryPanel = main.inventory_panel
	var inv := Story.inventory
	check(panel.open(), "인벤토리 열기")
	var bag_slots := 0
	for slot in panel.slots:
		if slot["kind"] == InventoryPanel.KIND_BAG:
			bag_slots += 1
			check((slot["rect"] as Rect2).size == Vector2(InventoryPanel.SLOT, InventoryPanel.SLOT) if bag_slots == 1 else true, "칸은 네모")
	check(bag_slots == InventoryPanel.BAG_COLS * InventoryPanel.BAG_ROWS, "소지품 칸 %d개 (네모 칸 격자)" % bag_slots)
	var in_screen := true
	for slot in panel.slots:
		if not Rect2(0, 0, 320, 180).encloses(slot["rect"]):
			in_screen = false
	check(in_screen, "모든 칸이 화면 안에 있음")
	check(panel.ids(InventoryPanel.KIND_WEAPON) == (["lab_gun"] as Array[String]) and panel.ids(InventoryPanel.KIND_ARMOR) == (["lab_suit"] as Array[String]), "장착 칸: 무기 한 칸 + 입은 갑옷")
	var armor_slots: Array = []
	for slot in panel.slots:
		if slot["kind"] == InventoryPanel.KIND_ARMOR:
			armor_slots.append(slot["slot"])
	check(armor_slots == ["helmet", "armor", "pants"], "갑옷류 장착 칸 세 개: 투구·갑옷·바지 %s" % [armor_slots])
	var pictures := true
	for slot in panel.slots:
		if slot["kind"] == InventoryPanel.KIND_ARMOR and slot["entry"] == null:
			if panel._slot_icon(slot["slot"]) == null or not panel._tag_of(slot).is_empty():
				pictures = false
	check(pictures, "빈 갑옷류 칸은 글씨가 아니라 그림(윤곽)으로 나타냄")
	check(not panel.ids(InventoryPanel.KIND_BAG).has("lab_gun") and panel.ids(InventoryPanel.KIND_BAG).has("heavy_gun"), "장착한 것은 장착 칸에, 나머지는 소지품 칸에")
	check(panel.ids(InventoryPanel.KIND_SKILL).size() == 5 and panel.ids(InventoryPanel.KIND_SKILL_Q) == (["shockwave"] as Array[String]), "보유 스킬 5칸 + Q 칸에 지정된 스킬")
	# 칸을 고르면(마우스를 올리면) 이름·능력치 글상자가 뜬다
	check(panel.select(InventoryPanel.KIND_BAG, "heavy_gun") and panel._tip.visible, "칸에 올리면 글상자가 뜸")
	var tip: String = panel._tip_label.text
	check(tip.begins_with(DB.item("heavy_gun").display_name) and tip.contains("사격") and tip.contains("근접"), "글상자: 이름 + 사격·근접 능력치")
	panel.select(InventoryPanel.KIND_BAG, "plated_coat")
	check(panel._tip_label.text.contains("최대 체력 +1"), "갑옷 글상자에 스탯 수정이 글로 보임")
	var empty_index := -1
	for i in panel.slots.size():
		if panel.slots[i]["kind"] == InventoryPanel.KIND_BAG and panel.slots[i]["entry"] == null:
			empty_index = i
	panel.selected = empty_index
	panel._update_view()
	check(not panel._tip.visible, "빈 칸에는 글상자가 없음")
	# 확정 동작
	panel.select(InventoryPanel.KIND_SKILL, "blink")
	panel.activate(true)
	check(inv.skill_ids[1] == "blink" and panel.ids(InventoryPanel.KIND_SKILL_F) == (["blink"] as Array[String]), "보유 스킬을 F 칸에 지정 (우클릭·F)")
	panel.select(InventoryPanel.KIND_BAG, "rapid_gun")
	panel.activate()
	check(inv.weapon_id == "rapid_gun" and _p().ammo.maximum == 18 and panel.ids(InventoryPanel.KIND_WEAPON) == (["rapid_gun"] as Array[String]), "소지품의 무기를 누르면 장착 → 바로 반영")
	check(panel.ids(InventoryPanel.KIND_BAG).has("lab_gun"), "빼낸 무기는 소지품 칸으로")
	panel.select(InventoryPanel.KIND_BAG, "lab_gun")
	panel.activate()
	panel.select(InventoryPanel.KIND_ARMOR, "lab_suit")
	panel.activate()
	check(inv.armor_id("armor") == "" and panel.ids(InventoryPanel.KIND_BAG).has("lab_suit"), "입은 갑옷 칸을 누르면 벗음")
	panel.select(InventoryPanel.KIND_BAG, "lab_suit")
	panel.activate()
	check(inv.armor_id("armor") == "lab_suit", "다시 입음")
	var vial := -1
	for i in panel.slots.size():
		if InventoryPanel.entry_id(panel.slots[i]["entry"]) == "heal_vial":
			vial = i
	check(vial >= 0 and panel._count_of(panel.slots[vial]) == inv.count("heal_vial"), "여러 개 가진 것은 칸에 개수가 보임")
	panel.select(InventoryPanel.KIND_BAG, "lab_memo")
	panel.activate()
	check(panel.reading and panel._doc_text.text.contains("시험 기록"), "자료는 인벤토리에서 읽을 수 있음")
	panel._close_document()
	check(not panel.reading and panel.is_open, "자료를 닫으면 칸 화면으로")
	# 방향키 이동
	panel.select(InventoryPanel.KIND_WEAPON)
	panel.move(Vector2.RIGHT)
	check(panel.slots[panel.selected]["kind"] == InventoryPanel.KIND_ARMOR, "방향키로 옆 칸 이동")
	panel.move(Vector2.DOWN)
	check(panel.slots[panel.selected]["kind"] == InventoryPanel.KIND_SKILL_F or panel.slots[panel.selected]["kind"] == InventoryPanel.KIND_SKILL_Q, "방향키로 아래 칸 이동")
	# 글상자가 화면 밖으로 나가지 않는지, 글이 폭을 넘지 않는지
	var label := UiText.make_label()
	var font := label.get_theme_font(&"font")
	label.free()
	var too_long: Array[String] = []
	for item in DB.items_sorted():
		var rows := 0
		for row in InventoryPanel.tooltip_text(item).split("\n"):
			var width := font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE_SMALL).x
			rows += maxi(ceili(width / (InventoryPanel.TIP_WIDTH - 6.0)), 1)
			if width > InventoryPanel.TIP_WIDTH - 6.0 and (row.contains(" · ") or row.contains("×") or row.contains("+")):
				too_long.append("%s: %s" % [item.id, row])
		if rows > 11:
			too_long.append("%s: %d줄" % [item.id, rows])
	check(too_long.is_empty(), "글상자 글이 칸 안에 들어감 %s" % [too_long])
	var outside := false
	for i in panel.slots.size():
		panel.selected = i
		panel._update_view()
		if panel._tip.visible:
			var r := Rect2(panel._tip.position, panel._tip.get_combined_minimum_size())
			if not Rect2(0, 0, 320, 180).encloses(r) or r.intersects(panel.slots[i]["rect"]):
				outside = true
	check(not outside, "글상자는 어느 칸에서도 화면 안에 뜨고 그 칸을 가리지 않음")
	panel.close()


func test_save_roundtrip() -> void:
	var inv := Story.inventory
	inv.equip("heavy_gun")
	inv.equip("plated_coat")
	inv.add("miner_cap")
	inv.equip("miner_cap")
	inv.set_skill(Inventory.SLOT_Q, "decoy")
	var vials := inv.count("heal_vial")
	check(main.saves.save_manual(), "장착을 바꾼 뒤 저장")
	inv.equip("lab_gun")
	inv.equip("lab_suit")
	inv.remove("heal_vial", vials)
	inv.set_skill(Inventory.SLOT_Q, "shockwave")
	main.load_save(StorySave.latest())
	_scripted()
	await step(4)
	inv = Story.inventory
	var p := _p()
	check(inv.weapon_id == "heavy_gun" and inv.armor_id("armor") == "plated_coat" and inv.armor_id("helmet") == "miner_cap" and inv.count("heal_vial") == vials, "불러오기: 인벤토리·장착 복원")
	check(p.weapon == DB.item("heavy_gun").weapon and p.health.maximum == DB.player.max_hp + 1, "불러오기: 장착 효과가 플레이어에 반영")
	check(p.skill.data.id == "decoy" and p.skill2 != null and p.skill2.data.id == "blink", "불러오기: Q·F 스킬 복원")


func test_speedrun_rules_unchanged() -> void:
	DB.game_config.story_mode = false
	await new_level("res://tests/maps/m1_test.txt")
	var p := level.player
	check(p.weapon.gun == DB.gun and p.weapon.melee == DB.melee and p.health.maximum == DB.player.max_hp and p.skill2 == null,
		"스피드런 규칙(story_mode 꺼짐)에서는 인벤토리 영향 없음")
	input.push(Vector2.ZERO, 1, 0, InputFrame.MELEE)
	await step(3)
	check(p.melee.is_active() and not p._gun.visible, "스피드런 규칙에서는 근접 그림 그대로 (총 숨김)")
	level.queue_free()
	level = null
	DB.game_config.story_mode = true
	await step(1)
