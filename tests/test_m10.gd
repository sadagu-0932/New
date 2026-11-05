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
	await test_cloak_follows_motion()
	await test_player_views()
	await test_gun_follows_aim()
	await test_bullet_looks()
	await test_hit_effects()
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
	check(p._gun.position.y < -2.0, "총은 어깨 높이에 붙음 (%.1f)" % p._gun.position.y)
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
	check(p._gun.animation == &"shoot", "쏘면 총 반동 그림")
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
