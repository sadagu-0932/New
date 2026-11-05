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
	test_export_preset()
	await test_tall_player_feet()
	if level != null:
		level.queue_free()
		level = null


func test_audio_silent_without_files() -> void:
	var ok := true
	for slot: String in ["shoot", "melee", "parry", "perfect", "hit", "boss"]:
		if Audio.has_sound(slot) or Audio.play(slot):
			ok = false
	check(ok, "효과음 슬롯 6개 — 파일이 없으면 오류 없이 무음")
	Events.player_shot.emit()
	Events.parried.emit(true)
	check(true, "소리 없는 상태에서 이벤트가 와도 문제없음")


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
