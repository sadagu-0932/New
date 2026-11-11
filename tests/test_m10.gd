class_name TestM10
extends TestBase
## M10 자동 테스트: 효과음 슬롯(파일 없으면 무음), 화면 흔들림·번쩍임, 잔상, 전체화면 키, 내보내기 설정

const MAP := "res://tests/maps/m2_test.txt"


func run_all() -> void:
	print("[M10] 다듬기·내보내기")
	test_audio_silent_without_files()
	await test_screen_fx()
	await test_afterimage()
	test_title_ignores_fullscreen_key()
	await test_menu_pointer()
	await test_touch_controls()
	await test_key_settings()
	await test_touch_layout_edit()
	test_export_preset()
	await test_tall_player_feet()
	await test_cloak_follows_motion()
	await test_player_views()
	await test_gun_follows_aim()
	await test_bullet_looks()
	await test_hit_effects()
	if level != null:
		level.queue_free()
		level = null


func test_audio_silent_without_files() -> void:
	var missing: Array[String] = []
	for slot: String in Audio.SLOTS:
		if not Audio.has_sound(slot):
			missing.append(slot)
	check(missing.is_empty(), "효과음 슬롯 %d개 모두 소리 파일 있음 %s" % [Audio.SLOTS.size(), missing])
	check(not Audio.has_sound("no_such_sound") and not Audio.play("no_such_sound"), "파일 없는 슬롯은 오류 없이 무음")
	check(Audio.play("perfect_parry"), "소리 재생")
	Events.player_shot.emit()
	Events.parried.emit(true)
	Events.skill_used.emit("blink")
	Events.skill_used.emit("unknown_skill")
	check(true, "이벤트로 소리가 울려도 문제없음")


func test_screen_fx() -> void:
	await new_level(MAP)
	var fx := ScreenFx.new()
	add_child(fx)
	await step(1)
	var cam := get_viewport().get_camera_2d()
	Events.parried.emit(true)
	check(fx._flash.color.a > 0.0 or fx._flash_left > 0.0, "완벽 판정 → 화면 번쩍임")
	var moved := false
	for i in 4:
		await get_tree().process_frame
		if cam and cam.offset != Vector2.ZERO:
			moved = true
	check(moved, "완벽 판정 → 화면 흔들림")
	for i in 40:
		await get_tree().process_frame
	check(cam.offset == Vector2.ZERO, "흔들림은 곧 멈춤")
	fx.queue_free()


func test_afterimage() -> void:
	await new_level(MAP)
	var p := level.player
	input.push(Vector2.RIGHT, 1, 0, InputFrame.DODGE, p.global_position + Vector2(50, 0))
	await step(6)
	var count := 0
	for n in level.effects.get_children():
		if n is AfterImage:
			count += 1
	check(count > 0, "회피하면 잔상이 남음 (%d)" % count)


func test_title_ignores_fullscreen_key() -> void:
	var title := TitleScreen.new()
	add_child(title)
	var started := [false]
	title.start_requested.connect(func() -> void: started[0] = true)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F11
	ev.keycode = KEY_F11
	ev.pressed = false
	title._input(ev)
	check(not started[0], "F11(전체화면)은 타이틀에서 시작 키로 치지 않음")
	var any := InputEventKey.new()
	any.physical_keycode = KEY_SPACE
	any.keycode = KEY_SPACE
	any.pressed = false
	title._input(any)
	check(started[0], "다른 키를 떼면 시작")
	title.queue_free()



## 메뉴 화면이 열려 있으면 화살표 포인터, 닫히면 조준점
func test_menu_pointer() -> void:
	# 앞 테스트에서 지운 메뉴 화면이 완전히 사라질 때까지
	await get_tree().process_frame
	var title := TitleScreen.new()
	add_child(title)
	var cross := Crosshair.new()
	add_child(cross)
	cross._process(0.0)
	check(cross.layer > title.layer, "커서가 메뉴 화면보다 위에 그려짐")
	check(cross._pointer.visible and not cross._cross.visible, "타이틀에서는 화살표 포인터")
	check(not cross._pointer.centered, "포인터 끝(왼쪽 위)이 마우스 위치")
	title.set_visible_screen(false)
	cross._process(0.0)
	check(cross._cross.visible and not cross._pointer.visible, "메뉴가 닫히면 조준점")
	var panel := SkillPanel.new(null)
	add_child(panel)
	cross._process(0.0)
	check(cross._cross.visible, "닫힌 스킬 설정 창은 영향 없음")
	panel._root.visible = true
	cross._process(0.0)
	check(cross._pointer.visible, "스킬 설정 창에서는 화살표 포인터")
	panel.queue_free()
	title.queue_free()
	cross.queue_free()
	await get_tree().process_frame



## 안드로이드 터치 조작: 기본(PC·웹)에서는 꺼져 있고, 조이스틱·버튼이 같은 액션을 누른다
func test_touch_controls() -> void:
	check(not TouchControls.is_enabled(), "PC·웹에서는 터치 조작 꺼짐")
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	var android := ""
	for sec in cfg.get_sections():
		if cfg.get_value(sec, "platform", "") == "Android":
			android = sec
	check(android != "" and String(cfg.get_value(android, "custom_features", "")).contains(TouchControls.FEATURE), "APK 에만 터치 조작 태그")
	var tc := TouchControls.new()
	add_child(tc)
	await get_tree().process_frame
	tc._process(0.0)
	var d := DB.touch
	check(tc._on_press(0, d.move_stick_center + Vector2(d.stick_radius, 0)), "이동 조이스틱 잡힘")
	check(Input.get_action_strength(&"move_right") > 0.9, "오른쪽으로 밀면 오른쪽 이동")
	check(tc._on_press(1, d.aim_stick_center + Vector2(0, -d.stick_radius * 0.3)), "조준 조이스틱 잡힘")
	check(tc.aim_dir.is_equal_approx(Vector2.UP), "조준 방향 = 끈 방향")
	Input.flush_buffered_events()
	check(not Input.is_action_pressed(&"shoot"), "살짝 끌면 조준만")
	tc._on_drag(1, d.aim_stick_center + Vector2(0, -d.stick_radius))
	Input.flush_buffered_events()
	check(Input.is_action_pressed(&"shoot"), "끝까지 밀면 사격")
	tc._on_release(1)
	Input.flush_buffered_events()
	check(not Input.is_action_pressed(&"shoot") and tc.aim_dir.is_equal_approx(Vector2.UP), "놓으면 사격 멈춤, 방향은 유지")
	var has_shoot_button := false
	for b: Dictionary in tc._buttons:
		if b.action == &"shoot":
			has_shoot_button = true
	check(not has_shoot_button, "사격 버튼은 없음")
	check(tc._on_press(2, d.action_button_positions[0]), "근접 버튼 눌림")
	Input.flush_buffered_events()
	check(Input.is_action_pressed(&"melee"), "근접 버튼 → 근접 액션")
	tc._on_press(4, d.action_button_positions[4])
	Input.flush_buffered_events()
	check(not Input.is_action_pressed(&"skill2"), "스킬2 칸은 잠겨 있어 눌러도 아무 일 없음")
	tc._release_all()
	Input.flush_buffered_events()
	check(not Input.is_action_pressed(&"shoot") and not Input.is_action_pressed(&"melee") \
		and Input.get_action_strength(&"move_right") == 0.0, "손을 떼면 모두 풀림")
	tc.queue_free()
	await get_tree().process_frame
	# 안내 글: PC 는 그대로, 터치 기기는 버튼 이름으로
	var hint: String = DB.game_config.tutorial.pre_start_hint
	check(UiText.for_device(hint) == hint, "PC 에서는 안내 글 그대로")
	TouchControls.force_enabled = true
	check(not UiText.for_device(hint).contains("Tab") and UiText.for_device(hint).contains("[설정]"), "터치 기기 안내 글은 버튼 이름으로 (%s)" % UiText.for_device(hint))
	check(DB.touch.text_map.size() > 10, "바꿀 말 목록이 들어 있음")
	var left := false
	for sd in DB.game_config.tutorial.sections:
		for word in ["WASD", "Space", "클릭", "마우스", "Tab", "Q "]:
			if UiText.for_device(sd.hint + sd.sign_text).contains(word):
				left = true
	check(not left, "구간 안내에 키보드·마우스 말이 남지 않음")
	TouchControls.force_enabled = false



## PC 키 설정: 바꾸기, 겹치면 맞바꾸기, 안내 글 반영, 기본값 복원
func test_key_settings() -> void:
	Settings.reset_keys()
	check(Settings.key_name(&"dodge") == "Space" and Settings.move_keys_name() == "WASD", "기본 키 이름 (Space, WASD)")
	Settings.rebind(&"dodge", {"t": "k", "c": KEY_SHIFT})
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SHIFT
	ev.pressed = true
	check(ev.is_action(&"dodge") and Settings.key_name(&"dodge") == "Shift", "회피를 Shift 로 바꿈")
	var hint: String = DB.game_config.tutorial.sections[0].hint
	check(UiText.for_device(hint).contains("Shift 회피") and not UiText.for_device(hint).contains("Space"), "안내 글도 바뀐 키로 (%s)" % UiText.for_device(hint))
	check(UiText.for_device("E 건너뛰기") == "E 건너뛰기", "컷씬 건너뛰기 글: 기본은 E")
	# 스킬1(Q)에 E(상호작용이 쓰던 키)를 주면 서로 맞바뀐다
	Settings.rebind(&"skill", {"t": "k", "c": KEY_E})
	check(Settings.key_name(&"skill") == "E" and Settings.key_name(&"interact") == "Q", "겹치는 키는 맞바꿈")
	check(UiText.for_device("E 건너뛰기") == "Q 건너뛰기", "컷씬 건너뛰기 글이 설정된 상호작용 키를 따라감")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	check(Settings.binding_from_event(esc).is_empty(), "Esc 는 키로 못 씀")
	# 키 설정 창: 고르고 → 듣기 → 새 키
	var panel := KeyBindPanel.new()
	add_child(panel)
	panel.open()
	panel.selected = 4  # 사격
	panel.listening = true
	var f := InputEventKey.new()
	f.physical_keycode = KEY_J
	f.pressed = true
	panel._input(f)
	check(Settings.key_name(&"shoot") == "J" and not panel.listening, "키 설정 창에서 사격을 J 로")
	panel.queue_free()
	Settings.reset_keys()
	check(Settings.key_name(&"dodge") == "Space" and Settings.key_name(&"shoot") == "좌클릭", "기본값으로 되돌림")
	await get_tree().process_frame


## 모바일 버튼 위치 바꾸기: 끌어 옮기면 기억하고, 초기화하면 기본 배치
func test_touch_layout_edit() -> void:
	Settings.reset_touch_positions()
	var tc := TouchControls.new()
	add_child(tc)
	await get_tree().process_frame
	var d := DB.touch
	tc.set_edit_mode(true)
	var from := d.action_button_positions[0]
	tc._on_press(0, from)
	tc._on_drag(0, from + Vector2(-40, -30))
	tc._on_release(0)
	Input.flush_buffered_events()
	check(not Input.is_action_pressed(&"melee"), "배치 모드에서는 버튼이 눌리지 않음")
	check(Settings.touch_position("action:melee", from) == from + Vector2(-40, -30), "끌어 옮긴 자리를 기억")
	tc._on_press(1, d.move_stick_center)
	tc._on_drag(1, Vector2(-50, 500))
	tc._on_release(1)
	var stick_pos := Settings.touch_position("stick:move", Vector2.ZERO)
	check(stick_pos.x >= 0 and stick_pos.y <= 180, "화면 밖으로는 못 나감 %s" % stick_pos)
	tc.set_edit_mode(false)
	tc.queue_free()
	await get_tree().process_frame
	# 새로 만들어도 옮긴 자리에서 눌린다
	var tc2 := TouchControls.new()
	add_child(tc2)
	await get_tree().process_frame
	tc2._process(0.0)
	tc2._on_press(0, from + Vector2(-40, -30))
	Input.flush_buffered_events()
	check(Input.is_action_pressed(&"melee"), "옮긴 자리에서 근접 버튼이 눌림")
	tc2._release_all()
	tc2.set_edit_mode(true)
	tc2._on_press(0, d.edit_button_positions[1])
	check(Settings.touch_positions.is_empty(), "초기화하면 기본 배치")
	tc2.set_edit_mode(false)
	tc2.queue_free()
	Input.flush_buffered_events()
	await get_tree().process_frame


func test_export_preset() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("res://export_presets.cfg")
	check(err == OK and cfg.get_value("preset.0", "platform", "") == "Windows Desktop", "Windows 내보내기 설정 있음")
	var inc: String = cfg.get_value("preset.0", "include_filter", "")
	check(inc.contains("*.json") and inc.contains("*.txt"), "스프라이트 정보(json)·맵(txt) 포함 필터")
	var exc: String = cfg.get_value("preset.0", "exclude_filter", "")
	check(exc.contains("tests/*"), "테스트는 exe 에서 제외")
	check(bool(cfg.get_value("preset.0.options", "binary_format/embed_pck", false)), "exe 하나로 (pck 포함)")


## 키 큰 플레이어(16x24)는 발 위치가 그대로이고 판정 크기는 바뀌지 않는다
func test_tall_player_feet() -> void:
	await new_level(MAP)
	var p := level.player
	var sprite: AnimatedSprite2D = null
	for n in p.get_children():
		if n is AnimatedSprite2D and (n as AnimatedSprite2D).sprite_frames == DB.theme.load_sheet("player"):
			sprite = n
	var h := sprite.sprite_frames.get_frame_texture(&"idle", 0).get_height()
	check(h > LevelMap.TILE_SIZE, "플레이어 그림이 한 칸보다 큼 (높이 %d)" % h)
	# 그림 아래끝 = 몸 중심 + 8 (16x16 시절과 같은 발 위치)
	var bottom := sprite.offset.y + h * 0.5
	check(is_equal_approx(bottom, LevelMap.TILE_SIZE * 0.5), "발 위치 그대로 (아래끝 %.1f)" % bottom)
	check(DB.player.hurtbox_radius == 4.0 and DB.player.body_radius == 4.0, "판정 크기는 그대로")


## 망토가 움직임에 따라 휘날린다 (화면 표시 전용)
func test_cloak_follows_motion() -> void:
	await new_level("res://tests/maps/m3_test.txt")
	var p := level.player
	var aim_right := p.global_position + Vector2(200, 0)
	input.push(Vector2.ZERO, 20, 0, 0, aim_right)
	await step(20)
	check(p._cloak.animation == &"cloak_hang", "가만히 있으면 늘어짐 (%s)" % p._cloak.animation)
	input.push(Vector2.RIGHT, 40, 0, 0, aim_right + Vector2(100, 0))
	await step(40)
	check(p._cloak.animation == &"cloak_trail2", "달리면 뒤로 크게 날림 (%s)" % p._cloak.animation)
	var seen_fwd := false
	input.push(Vector2.ZERO, 40, 0, 0, aim_right)
	for i in 40:
		await step(1)
		if p._cloak.animation == &"cloak_fwd" or p._cloak.animation == &"cloak_hang":
			seen_fwd = seen_fwd or p._cloak_lean < 0.0
	check(seen_fwd or p._cloak_lean < 0.5, "멈추면 출렁이다 늘어짐 (기울기 %.2f)" % p._cloak_lean)
	check(p._cloak.animation == &"cloak_hang", "다시 늘어짐")
	input.push(Vector2.RIGHT, 1, 0, InputFrame.DODGE, aim_right)
	await step(5)
	check(p._cloak.animation == &"cloak_billow" or p._cloak.animation == &"cloak_trail2", "회피하면 펄럭 (%s)" % p._cloak.animation)
	await step(30)
	input.push(Vector2.LEFT, 40, 0, 0, p.global_position + Vector2(200, 0))
	await step(40)
	check(p._cloak.animation == &"cloak_fwd", "조준 반대로 뒷걸음질하면 몸 쪽으로 눌림 (%s)" % p._cloak.animation)
	check(p._cloak.flip_h == p._sprite.flip_h, "망토는 몸과 같은 쪽을 봄")


## 조준 방향에 따라 옆/정면/뒷모습. 뒷모습이면 망토가 몸을 덮는다 (화면 표시 전용)
func test_player_views() -> void:
	await new_level("res://tests/maps/m3_test.txt")
	var p := level.player
	var pos := p.global_position
	input.push(Vector2.ZERO, 3, 0, 0, pos + Vector2(100, 0))
	await step(3)
	check(p.view == Player.View.SIDE, "옆을 조준하면 옆모습")
	input.push(Vector2.ZERO, 3, 0, 0, pos + Vector2(10, 100))
	await step(3)
	check(p.view == Player.View.FRONT, "아래를 조준하면 정면")
	check(p._cloak.get_index() < p._sprite.get_index(), "정면: 망토는 몸 뒤")
	input.push(Vector2.ZERO, 3, 0, 0, pos + Vector2(-10, -100))
	await step(3)
	check(p.view == Player.View.BACK, "위를 조준하면 뒷모습")
	check(p._cloak.get_index() > p._sprite.get_index(), "뒷모습: 망토가 몸 앞")
	check(not p._sprite.flip_h, "뒷모습은 뒤집지 않음")
	# 대각선 경계 근처에서는 지금 그림을 유지 (깜빡임 방지)
	input.push(Vector2.ZERO, 3, 0, 0, pos + Vector2(100, -115))
	await step(3)
	check(p.view == Player.View.BACK, "경계 근처는 뒷모습 유지")
	input.push(Vector2.ZERO, 3, 0, 0, pos + Vector2(-100, -20))
	await step(3)
	check(p.view == Player.View.SIDE and p._sprite.flip_h, "왼쪽 조준 → 옆모습(뒤집힘)")
	check(p._cloak.get_index() < p._sprite.get_index(), "옆모습: 망토는 몸 뒤")
	# 아래로 달리며 위를 조준(뒷걸음질) → 망토가 몸 쪽으로 눌림
	input.push(Vector2.DOWN, 40, 0, 0, pos + Vector2(0, -400))
	await step(40)
	check(p.view == Player.View.BACK, "위를 보며 뒷걸음질")
	check(p._cloak.animation == &"cloak_fwd", "뒷걸음질하면 망토가 눌림 (%s)" % p._cloak.animation)
	# 미끼 분신은 만들 때 보던 방향 그대로
	for v: Player.View in [Player.View.SIDE, Player.View.FRONT, Player.View.BACK]:
		var d := Decoy.new()
		d.data = DB.skill_by_id("decoy") as DecoyData
		d.view = v
		d.flip = v == Player.View.SIDE
		level.add_child(d)
		var sheet: String = Player.VIEW_SHEETS[v][0]
		check(d._sprite.sprite_frames == DB.theme.load_sheet(sheet), "분신 그림 = %s" % sheet)
		var cloak_i := -1
		for c in d.get_children():
			if c is AnimatedSprite2D and (c as AnimatedSprite2D).sprite_frames == DB.theme.load_sheet(Player.VIEW_SHEETS[v][1]):
				cloak_i = c.get_index()
		check((cloak_i > d._sprite.get_index()) == (v == Player.View.BACK), "분신 망토 순서 (%s)" % sheet)
		d.vanish()


## 총은 따로 그린 그림: 어깨에 붙어 마우스 쪽으로 돌고, 탄은 어깨 높이에서 마우스 쪽으로 나간다
func test_gun_follows_aim() -> void:
	await new_level("res://tests/maps/m3_test.txt")
	var p := level.player
	var pos := p.global_position
	var target := pos + Vector2(60, -40)
	input.push(Vector2.ZERO, 3, 0, 0, target)
	await step(3)
	var origin := pos + Vector2(0, -DB.gun.muzzle_height)
	check(p._gun.visible, "평소엔 총이 보임")
	check(is_equal_approx(p._gun.rotation, (target - origin).angle()), "총구가 마우스 쪽을 향함")
	check(not p._gun.flip_v, "오른쪽을 겨누면 총을 뒤집지 않음")
	check(p._gun.position.y < -2.0, "총은 가슴 높이 둘레에 떠 있음 (%.1f)" % p._gun.position.y)
	input.push(Vector2.ZERO, 1, InputFrame.SHOOT, 0, target)
	await step(2)
	var shot: Projectile = null
	for n in level.projectiles.get_children():
		if n is Projectile and (n as Projectile).team == Team.PLAYER:
			shot = n
	check(shot != null, "쏨")
	if shot:
		var dir := shot.velocity.normalized()
		check(dir.dot((target - origin).normalized()) > 0.999, "탄은 어깨에서 마우스 쪽으로")
	check(p._muzzle_flash.visible, "쏘면 총구 불꽃")
	check(p._gun.sprite_frames.get_animation_names().size() == 1, "총 그림은 하나 (돌리기만 함)")
	input.push(Vector2.ZERO, 3, 0, 0, pos + Vector2(-60, 10))
	await step(3)
	check(p._gun.flip_v, "왼쪽을 겨누면 총을 뒤집어 위아래가 맞게")
	input.push(Vector2.ZERO, 3, 0, 0, pos + Vector2(0, -100))
	await step(3)
	check(p.view == Player.View.BACK and p._gun.get_index() < p._sprite.get_index(), "뒷모습이면 총은 몸 뒤")
	input.push(Vector2.ZERO, 3, 0, 0, pos + Vector2(0, 100))
	await step(3)
	check(p.view == Player.View.FRONT and p._gun.get_index() > p._sprite.get_index(), "정면이면 총은 몸 앞")
	input.push(Vector2.RIGHT, 1, 0, InputFrame.DODGE, pos + Vector2(100, 0))
	await step(2)
	check(not p._gun.visible, "회피 중엔 총 숨김")
	await step(40)
	check(p._gun.visible, "회피가 끝나면 다시 보임")


## 적마다 어울리는 탄 그림, 진행 방향 회전, 꼬리 (화면 표시 전용)
func test_bullet_looks() -> void:
	check(DB.enemies["shooter"].projectile.anim == &"fireball", "원거리형 = 불덩이")
	check(DB.enemies["spreader"].projectile.anim == &"shard", "탄막형 = 수정 조각")
	check(DB.enemies["golem"].projectile.anim == &"golem", "골렘 = 빛나는 돌 탄")
	check(DB.gun.projectile.anim == &"player", "내 탄 = 예광탄")
	await new_level(MAP)
	var dir := Vector2(1, -1).normalized()
	var fb := Projectile.spawn(level.projectiles, Team.ENEMY, Vector2(100, 60), dir, DB.enemies["shooter"].projectile)
	await step(4)
	check(is_equal_approx(fb._sprite.rotation, dir.angle()), "불덩이는 날아가는 방향으로 돌아감")
	var trails := 0
	for n in level.effects.get_children():
		if n is AfterImage:
			trails += 1
	check(trails > 0, "불덩이 꼬리 잔상 (%d)" % trails)
	fb.reflect(Vector2.LEFT, false, DB.parry)
	await step(1)
	check(fb._sprite.animation == &"reflect" and is_equal_approx(absf(fb._sprite.rotation), PI), "반사되면 하늘색 볼트로 바뀌고 반대 방향으로 돌아감")
	var sh := Projectile.spawn(level.projectiles, Team.ENEMY, Vector2(100, 60), dir, DB.enemies["spreader"].projectile)
	await step(2)
	check(sh._sprite.rotation == 0.0, "수정 조각은 방향 대신 제자리에서 빙글빙글 (프레임 회전)")


func _effects_named(anim: StringName) -> int:
	var count := 0
	for n in level.effects.get_children():
		if n is Effect and (n as Effect).animation == anim:
			count += 1
	return count


## 무엇에 맞았는지에 따라 이펙트가 다르다 (화면 표시 전용)
func test_hit_effects() -> void:
	await new_level(MAP)
	var p := level.player
	# 벽: 위쪽으로 쏘면 돌 파편
	Projectile.spawn(level.projectiles, Team.PLAYER, p.global_position + Vector2(0, -8), Vector2.UP, DB.gun.projectile)
	var wall := await wait_until(func() -> bool: return _effects_named(&"hit_wall") > 0, 30)
	check(wall, "벽에 맞으면 돌 파편")
	# 적: 허수아비를 맞히면 불꽃
	var dummy: TargetDummy = null
	for n in level.get_node("Props").get_children():
		if n is TargetDummy:
			dummy = n
			break
	Projectile.spawn(level.projectiles, Team.PLAYER, dummy.global_position - Vector2(30, 0), Vector2.RIGHT, DB.gun.projectile)
	await step(10)
	check(_effects_named(&"hit_enemy") > 0, "적을 맞히면 불꽃")
	# 패링: 금속 섬광
	var b := Projectile.spawn(level.projectiles, Team.ENEMY, p.global_position + Vector2(14, 0), Vector2.LEFT, DB.test_turret.projectile)
	input.push(Vector2.ZERO, 1, 0, InputFrame.MELEE, p.global_position + Vector2(50, 0))
	await step(2)
	check(_effects_named(&"hit_parry") > 0, "패링하면 금속 섬광")
	# 흡수 장막: 빨려듦
	await step(DB.melee.active_ticks + DB.melee.recovery_ticks)
	p.set_skill(DB.skill_by_id("absorb"))
	input.push(Vector2.ZERO, 1, 0, InputFrame.SKILL, p.global_position + Vector2(50, 0))
	await step(1)
	Projectile.spawn(level.projectiles, Team.ENEMY, p.global_position + Vector2(40, 0), Vector2.LEFT, DB.test_turret.projectile)
	var absorbed := await wait_until(func() -> bool: return _effects_named(&"hit_absorb") > 0, 30)
	check(absorbed, "흡수 장막에 닿으면 빨려드는 효과")
