class_name TestM1
extends TestBase
## M1 자동 테스트: 이동, 회피(거리·무적·쿨타임), 벽 충돌, 결정론, 디버그 구간 이동

const MAP := "res://tests/maps/m1_test.txt"
const RIGHT := Vector2.RIGHT


func run_all() -> void:
	print("[M1] 이동·회피")
	await test_move()
	await test_diagonal_speed()
	await test_dodge()
	await test_dodge_cooldown()
	await test_dodge_uses_aim_when_idle()
	await test_wall_blocks()
	await test_determinism()
	await test_debug_section_warp()
	await test_input_map_live()


func _player_data() -> PlayerData:
	return DB.player


func _dodge_data() -> DashDodgeData:
	return DB.dodge as DashDodgeData


func test_move() -> void:
	await new_level(MAP)
	var p := level.player
	var start := p.global_position
	input.push(RIGHT, 30)
	await step(30)
	check_near(p.global_position.x - start.x, _player_data().move_speed * 30.0 / 60.0, 0.5, "오른쪽 30틱 이동 거리")
	check_near(p.global_position.y, start.y, 0.01, "세로 위치 그대로")


func test_diagonal_speed() -> void:
	await new_level(MAP)
	var p := level.player
	var start := p.global_position
	input.push(Vector2(1, 1).normalized(), 20)
	await step(20)
	check_near(p.global_position.distance_to(start), _player_data().move_speed * 20.0 / 60.0, 0.5, "대각선도 같은 속도")


func test_dodge() -> void:
	await new_level(MAP)
	var p := level.player
	var d := _dodge_data()
	var start := p.global_position
	input.push(RIGHT, 1, 0, InputFrame.DODGE)
	await step(1)
	check(p.state == Player.State.DODGE, "회피 시작")
	check(p.is_invulnerable(), "회피 시작 직후 무적")
	await step(d.duration_ticks - 1)
	check(p.state == Player.State.NORMAL, "지속 틱 후 회피 종료")
	check_near(p.global_position.x - start.x, d.speed * d.duration_ticks / 60.0, 0.5, "회피 이동 거리")
	check(not p.is_invulnerable(), "회피 끝나면 무적 해제")


func test_dodge_cooldown() -> void:
	await new_level(MAP)
	var p := level.player
	var d := _dodge_data()
	input.push(Vector2.ZERO, 1, 0, InputFrame.DODGE)
	await step(d.duration_ticks)
	check(p.state == Player.State.NORMAL, "첫 회피 끝")
	input.push(Vector2.ZERO, 1, 0, InputFrame.DODGE)
	await step(1)
	check(p.state == Player.State.NORMAL, "쿨타임 중에는 회피 불가")
	await step(d.cooldown_ticks)
	input.push(Vector2.ZERO, 1, 0, InputFrame.DODGE)
	await step(1)
	check(p.state == Player.State.DODGE, "쿨타임 후 다시 회피 가능")


func test_dodge_uses_aim_when_idle() -> void:
	await new_level(MAP)
	var p := level.player
	var start := p.global_position
	# 이동 입력 없이 회피 → 조준 방향(아래)으로
	input.push(Vector2.ZERO, 1, 0, InputFrame.DODGE, start + Vector2(0, 50))
	await step(_dodge_data().duration_ticks)
	check(p.global_position.y > start.y + 10.0, "이동 입력 없으면 조준 방향으로 회피")


func test_wall_blocks() -> void:
	await new_level(MAP)
	var p := level.player
	input.push(RIGHT, 240)
	await step(240)
	# 테스트 맵 오른쪽 벽 안쪽 면 x = 11*16 = 176
	var max_x := 176.0 - _player_data().body_radius
	check(p.global_position.x <= max_x + 0.6, "벽을 뚫지 않음 (x=%.2f, 한계 %.2f)" % [p.global_position.x, max_x])
	check(p.global_position.x >= max_x - 1.0, "벽 앞까지는 감")


## project.godot 의 Input Map 이 제대로 읽히고, 실제 장치 입력 경로로 움직이는지
func test_input_map_live() -> void:
	var expected := {
		&"move_left": KEY_A, &"move_right": KEY_D, &"move_up": KEY_W, &"move_down": KEY_S,
		&"dodge": KEY_SPACE, &"skill": KEY_Q, &"interact": KEY_E, &"restart": KEY_R,
		&"pause": KEY_ESCAPE, &"debug_hitboxes": KEY_F1, &"debug_god": KEY_F2,
		&"debug_prev_section": KEY_F3, &"debug_next_section": KEY_F4,
	}
	var ok := true
	for action: StringName in expected:
		var events := InputMap.action_get_events(action)
		if events.size() != 1 or not (events[0] is InputEventKey) \
				or (events[0] as InputEventKey).physical_keycode != expected[action]:
			ok = false
			print("    입력 맵 이상: ", action, " ", events)
	check(ok, "키보드 입력 맵 (WASD·Space·Q·E·R·Esc·F1~F4)")
	var shoot := InputMap.action_get_events(&"shoot")
	var melee := InputMap.action_get_events(&"melee")
	check(shoot.size() == 1 and (shoot[0] as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT, "좌클릭 = 사격")
	check(melee.size() == 1 and (melee[0] as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT, "우클릭 = 근접")

	await new_level(MAP)
	PlayerInput.use_live_input()
	var p := level.player
	var start := p.global_position
	Input.action_press(&"move_right")
	await step(10)
	Input.action_release(&"move_right")
	check(p.global_position.x > start.x + 5.0, "실제 입력 경로로 이동 (D 키)")
	# 엔진은 물리 틱 도중 들어온 입력을 다음 틱에 반영하므로 2틱 진행
	Input.action_press(&"dodge")
	await step(2)
	check(p.state == Player.State.DODGE, "실제 입력 경로로 회피 (Space)")
	Input.action_release(&"dodge")
	await step(1)


## 같은 입력이면 같은 결과 (리플레이 기반)
func test_determinism() -> void:
	var results: Array[Vector2] = []
	for run in 2:
		await new_level(MAP)
		input.push(Vector2(1, 0.3).normalized(), 25)
		input.push(RIGHT, 1, 0, InputFrame.DODGE)
		input.push(Vector2(0, 1), 40)
		input.push(Vector2(-1, -1).normalized(), 1, 0, InputFrame.DODGE)
		input.push(Vector2(1, -1).normalized(), 60)
		await step(140)
		results.append(level.player.global_position)
	check(results[0] == results[1], "같은 입력 → 같은 위치 %s / %s" % [results[0], results[1]])


func test_debug_section_warp() -> void:
	await new_level(MAP)
	Events.debug_section_step.emit(1)
	check(level.player.global_position == LevelMap.cell_center(Vector2i(10, 3)), "F4: 1구간 지점으로 이동")
	Events.debug_section_step.emit(1)
	check(level.player.global_position == LevelMap.cell_center(Vector2i(10, 5)), "F4: 2구간 지점으로 이동")
	Events.debug_section_step.emit(1)
	check(level.current_section == 2, "마지막 구간에서 더 가지 않음")
	Events.debug_section_step.emit(-1)
	Events.debug_section_step.emit(-1)
	check(level.player.global_position == LevelMap.cell_center(Vector2i(1, 3)), "F3: 시작 지점으로 돌아옴")
	# 히트박스 표시를 켜도 문제 없이 그려지는지
	Debug.show_hitboxes = true
	Events.debug_flags_changed.emit()
	await step(2)
	Debug.show_hitboxes = false
	Events.debug_flags_changed.emit()
	check(true, "히트박스 표시 토글")
