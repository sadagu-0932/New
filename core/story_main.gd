extends Node
## 스토리판 진입점·화면 흐름.
## 타이틀(새 게임 / 이어하기 / 설정 / 종료) → 프롤로그(기존 튜토리얼) → "한나절 뒤" → 바깥 세상
## 바깥 세상은 한 장으로 이어진 맵(world)이라 연구소·광산촌·숲·골렘 터를 걸어서 오간다 (화면 전환 없음).
## 웨이스톤 순간이동, 저장·불러오기·부활, 웨이스톤 활성화, 획득물·자료 읽기를 여기서 잇는다.
## 스피드런 기능(타이머·스플릿·리더보드·기록 화면·어트랙트 모드·관리자 창)은 만들지 않는다.
## (스피드런판 진입점은 core/main.gd 로 main 브랜치에서 쓴다)

var run: RunController
var title: StoryTitleScreen
var inventory_panel: InventoryPanel
var map_panel: MapPanel
var saves: StorySaveManager
var pause_menu: StoryPauseMenu
var save_list: SaveListPanel
var dialogue_box: DialogueBox

var _notice_layer: CanvasLayer
var _notice: Label
var _notice_left: float = 0.0
## 자료를 주운 뒤 바로 펼쳐 보여줄 것 (다음 틱에 연다)
var _pending_document: String = ""


func _ready() -> void:
	add_child(Hud.new())
	add_child(HintDisplay.new())
	add_child(BossBar.new())
	add_child(DialoguePlayer.new())
	dialogue_box = DialogueBox.new()
	add_child(dialogue_box)
	add_child(Crosshair.new())
	if TouchControls.is_enabled():
		add_child(TouchControls.new())
	pause_menu = StoryPauseMenu.new()
	pause_menu.resume_requested.connect(func() -> void:
		if run != null:
			run.set_paused(false))
	pause_menu.save_requested.connect(func() -> void: saves.save_manual())
	pause_menu.load_requested.connect(func() -> void: save_list.open())
	pause_menu.title_requested.connect(go_title)
	add_child(pause_menu)
	add_child(Toast.new())
	saves = StorySaveManager.new()
	add_child(saves)
	add_child(ScreenFx.new())
	# 스킬 지정·장착·아이템은 인벤토리 화면에서 (스피드런판의 Tab 스킬 창 자리)
	inventory_panel = InventoryPanel.new()
	add_child(inventory_panel)
	map_panel = MapPanel.new()
	map_panel.teleport_requested.connect(teleport)
	add_child(map_panel)
	_build_notice()
	title = StoryTitleScreen.new()
	title.new_game_requested.connect(start_new_game)
	title.continue_requested.connect(continue_game)
	add_child(title)
	# 저장 목록은 타이틀·일시정지 메뉴보다 나중에 넣는다 (열려 있을 때 입력을 먼저 받게)
	save_list = SaveListPanel.new()
	save_list.save_chosen.connect(load_save)
	add_child(save_list)
	if Debug.enabled:
		add_child(DebugOverlay.new())
	Events.return_to_title.connect(go_title)
	Events.prologue_finished.connect(_on_prologue_finished)
	Events.story_respawn_requested.connect(respawn)
	Events.loadout_changed.connect(_apply_loadout)
	Events.area_exit_entered.connect(_on_area_exit)
	Events.waystone_touched.connect(_on_waystone_touched)
	Events.item_picked.connect(_on_item_picked)
	Events.document_read.connect(_on_document_read)
	if DB.game_config.start_fullscreen:
		set_fullscreen(true)
	go_title()
	if OS.get_cmdline_user_args().has("--selfcheck"):
		_selfcheck()


## 내보낸 실행 파일 점검용: `demo-story.exe --headless -- --selfcheck`
## 모든 지역을 한 번씩 띄워 보고 결과를 출력한 뒤 끝낸다 (data 폴더 읽기·맵·소품이 빌드 안에서도 되는지 확인).
## 실제 저장 파일은 건드리지 않는다.
func _selfcheck() -> void:
	StorySave.dir_override = "user://selfcheck_saves"
	StorySave.clear_all()
	var problems: Array[String] = []
	start_new_game()
	await get_tree().physics_frame
	if _player() == null or run.level.tutorial == null:
		problems.append("프롤로그를 띄우지 못함")
	Events.prologue_finished.emit()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var world := DB.area(DB.story.after_prologue_area)
	if world == null or _player() == null or run.level.area != world:
		problems.append("바깥 세상을 띄우지 못함")
	else:
		if run.level.props.get_child_count() < world.level_map().props.size():
			problems.append("소품이 모자람")
		# 이름 붙은 지점마다 한 번씩 서 본다 (타일 그림·지역 판정)
		for mark: String in ["lab_gate", "village_gate", "lair_gate"]:
			var cell := world.landmark(mark)
			_player().teleport(LevelMap.cell_center(cell))
			await get_tree().physics_frame
			await get_tree().physics_frame
			var z := world.zone_at(cell)
			if cell.x < 0 or z == null or run.level.area_director.zone_id != z.id:
				problems.append("지역 판정 실패: %s" % mark)
	StorySave.clear_all()
	print("SELFCHECK %s · 아이템 %d · 지역 %d · 적 수치 %d %s" % ["OK" if problems.is_empty() else "FAIL",
		DB.items.size(), DB.areas.size(), DB.enemies.size(), problems])
	get_tree().quit(0 if problems.is_empty() else 1)


func set_fullscreen(value: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		set_fullscreen(DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()


## 화면 가운데 글 (검은 바탕): 이번 범위의 끝
func _build_notice() -> void:
	_notice_layer = CanvasLayer.new()
	_notice_layer.layer = 98
	add_child(_notice_layer)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_notice_layer.add_child(bg)
	_notice = UiText.make_label()
	_notice.set_anchors_preset(Control.PRESET_FULL_RECT)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice_layer.add_child(_notice)
	_notice_layer.visible = false


func _player() -> Player:
	return run.level.player if run != null and run.level != null else null


func _free_run() -> void:
	if run != null:
		# 일시정지 메뉴에서 나갈 때 메뉴도 닫히게
		run.set_paused(false)
		remove_child(run)
		run.queue_free()
		run = null
	inventory_panel.close()
	inventory_panel.run = null
	map_panel.close()
	map_panel.run = null
	saves.run = null
	_pending_document = ""


## 지금 지역(Story.area)의 런을 띄운다.
## state: 불러온 저장의 "pos"·"hp"·"ammo", 또는 지역 이동의 "spawn"(도착 지점 번호)·"hp"·"ammo"
func _start_run(state: Dictionary = {}) -> void:
	_free_run()
	title.set_visible_screen(false)
	save_list.close()
	_notice_layer.visible = false
	_notice_left = 0.0
	get_tree().paused = false
	PlayerInput.use_live_input()
	var setup := RunSetup.from_config(DB.game_config)
	var area := DB.area(Story.area)
	if area != null and not area.map_file.is_empty():
		# 스토리 지역: 지역 맵을 쓴다 (프롤로그는 튜토리얼 맵 그대로)
		setup.tutorial = null
		setup.area = area
	setup.skill = Story.inventory.skill_data(Inventory.SLOT_Q)
	run = RunController.new(setup)
	run.pending_state = state
	add_child(run)
	# 입력 처리 순서: UI(인벤토리·지도·메뉴)가 런보다 먼저 받도록 맨 앞에 둔다
	move_child(run, 0)
	inventory_panel.run = run
	map_panel.run = run
	saves.run = run
	_apply_loadout()


## 인벤토리의 장착·스킬 지정을 지금 플레이어에게 반영한다 (런 시작 때와 바뀔 때마다)
func _apply_loadout() -> void:
	var p := _player()
	if p == null:
		return
	var inv := Story.inventory
	var q := inv.skill_data(Inventory.SLOT_Q)
	if q != null and (p.skill == null or p.skill.data != q):
		p.set_skill(q)
		run.setup.skill = q
	var f := inv.skill_data(Inventory.SLOT_F)
	if (p.skill2.data if p.skill2 != null else null) != f:
		p.set_skill2(f)
	p.apply_loadout()


## 새 게임: 프롤로그(기존 튜토리얼)부터. 시작하자마자 입구에서 자동저장
func start_new_game() -> void:
	Story.reset()
	_start_run()
	saves.save_auto("start")


## 이어하기: 저장 목록을 연다 (최신이 맨 위에 골라져 있다)
func continue_game() -> void:
	save_list.open()


## 저장 하나를 불러온다
func load_save(save: Dictionary) -> void:
	var state: Dictionary = save.get("state", {})
	if state.is_empty():
		return
	Story.from_dict(state.get("story", {}))
	_start_run(state)
	saves.mark_loaded(state)


## 죽은 뒤: 마지막 저장 지점에서 부활 (저장이 하나도 없으면 새 게임)
func respawn() -> void:
	var save := StorySave.latest()
	if save.is_empty():
		start_new_game()
	else:
		load_save(save)


## 다른 지역으로 넘어간다 (화면이 바뀐다). 체력·탄약은 그대로 들고 간다
## 바깥 세상은 한 장이라 걸어 다닐 때는 쓰이지 않는다 — 프롤로그 ↔ 세계 같은 맵 전환용
func travel(area_id: String, spawn_index: int) -> void:
	if DB.area(area_id) == null:
		push_warning("없는 지역: %s" % area_id)
		return
	var state := _carry_state()
	state["spawn"] = spawn_index
	Story.area = area_id
	_start_run(state)
	Events.toast.emit(DB.area(area_id).display_name)


## 웨이스톤 id → 그 탑이 있는 지역
static func area_of_waystone(waystone_id: String) -> AreaData:
	for a: AreaData in DB.areas.values():
		if a.waystone_index(waystone_id) >= 0:
			return a
	return null


## 활성화한 웨이스톤으로 순간이동 (지도 화면에서 고름). 전투 중·보스방에서는 불가
func teleport(waystone_id: String) -> bool:
	var area := area_of_waystone(waystone_id)
	var p := _player()
	if area == null or not Story.waystones.has(waystone_id) or p == null or CombatState.is_restricted(get_tree()):
		return false
	var pos := area.waystone_arrival(waystone_id)
	if area.id == Story.area:
		# 같은 세계 안: 화면을 바꾸지 않고 그 자리로 옮긴다
		p.teleport(pos)
		Effect.spawn(&"perfect", pos, 0.0, 2.0)
	else:
		var state := _carry_state()
		state["pos"] = [pos.x, pos.y]
		Story.area = area.id
		_start_run(state)
	Events.toast.emit(area.place_name(pos))
	return true


func _carry_state() -> Dictionary:
	var p := _player()
	if p == null:
		return {}
	return {"hp": p.health.current, "ammo": p.ammo.current}


func _on_area_exit(exit: Resource) -> void:
	var data := exit as AreaExitData
	if data == null or run == null:
		return
	if data.target_area.is_empty():
		_show_ending(data.end_text)
	else:
		# 물리 처리 도중에 레벨을 갈아치우지 않도록 틱이 끝난 뒤에 넘어간다
		travel.call_deferred(data.target_area, data.target_spawn)


## 웨이스톤 활성화: 지도에 주변이 밝혀지고, 회복 + 자동저장
func _on_waystone_touched(node: Node2D) -> void:
	var waystone := node as Waystone
	var p := _player()
	if waystone == null or waystone.data == null or p == null or Story.waystones.has(waystone.data.id):
		return
	Story.waystones.append(waystone.data.id)
	waystone.refresh()
	p.health.current = p.health.maximum
	Events.player_hp_changed.emit(p.health.current, p.health.maximum)
	p.ammo.set_current(p.ammo.maximum)
	Effect.spawn(&"perfect", waystone.global_position, 0.0, 3.0)
	Audio.play("ui_confirm")
	# 전투 중에 닿았으면 저장은 건너뛴다 (활성화·회복은 된다)
	saves.save_auto("waystone")
	Events.toast.emit(DB.story.text_waystone_activated % Settings.key_name(&"map"))


func _on_item_picked(item_id: String) -> void:
	var item := DB.item(item_id)
	if item == null:
		return
	Events.toast.emit(DB.story.text_item_picked % item.display_name)
	Audio.play("ui_confirm")
	# 자료는 줍자마자 펼쳐 보여준다 (자료 발견 연출)
	if item.category == ItemData.Category.DOCUMENT:
		_pending_document = item_id


## 자료를 읽은 뒤: 그 자료에 딸린 글이 있으면 흘려 보낸다 (data/story.tres 의 "read:<id>")
func _on_document_read(item_id: String) -> void:
	var key := "read:%s" % item_id
	var seen := "seen:%s" % key
	if DB.story.lines.has(key) and not Story.has_flag(seen):
		Story.set_flag(seen)
		Events.story_triggered.emit(key)


## 프롤로그 끝 ("한나절 뒤" 암전 뒤) → 바깥 세상의 연구소에서 깨어남. 스킬 칸이 하나 더 열린다
func _on_prologue_finished() -> void:
	Story.set_flag("prologue_done")
	Story.area = DB.story.after_prologue_area
	_start_run()
	saves.save_auto("start")


## 이번 작업 범위의 끝: 글을 보여주고 타이틀로
func _show_ending(text: String) -> void:
	_free_run()
	_notice.text = text
	_notice_layer.visible = true
	_notice_left = DB.story.end_seconds


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			go_title()
	if not _pending_document.is_empty() and inventory_panel.can_open() and not inventory_panel.is_open:
		var id := _pending_document
		_pending_document = ""
		inventory_panel.read_document(id)


func go_title() -> void:
	_free_run()
	PlayerInput.stop_recording()
	PlayerInput.use_live_input()
	get_tree().paused = false
	_notice_layer.visible = false
	_notice_left = 0.0
	save_list.close()
	title.can_continue = StorySave.has_any()
	title.set_visible_screen(true)
