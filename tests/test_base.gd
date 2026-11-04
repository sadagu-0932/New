class_name TestBase
extends Node
## 헤드리스 자동 테스트 공통 도구.
## 입력을 ScriptedInputSource 로 흘려 넣고 틱 단위로 진행시킨 뒤 상태를 검사한다.
## 규칙: step() 이 끝나면 항상 "다음 틱 처리 직전" 시점이다.

var failures: int = 0
var checks: int = 0
var input: ScriptedInputSource
var level: Level


## 하위 클래스에서 구현: 테스트를 순서대로 실행
func run_all() -> void:
	pass


## 테스트용 맵으로 새 레벨을 띄운다
func new_level(map_path: String) -> Level:
	if level != null:
		level.queue_free()
		await get_tree().physics_frame
	Game.reset_run()
	Debug.god_mode = false
	input = ScriptedInputSource.new()
	PlayerInput.source = input
	level = Level.new()
	level.map_path = map_path
	add_child(level)
	await get_tree().physics_frame
	return level


## 실제 튜토리얼 맵으로 새 레벨을 띄운다
func new_tutorial_level() -> Level:
	if level != null:
		level.queue_free()
		await get_tree().physics_frame
	Game.reset_run()
	Debug.god_mode = false
	input = ScriptedInputSource.new()
	PlayerInput.source = input
	level = Level.new()
	level.tutorial = DB.game_config.tutorial
	add_child(level)
	await get_tree().physics_frame
	return level


## 레벨 안에 적을 만든다 (key = DB.enemies 의 이름)
func spawn_enemy(key: String, pos: Vector2) -> Enemy:
	var script: GDScript = null
	for spawn: Array in Level.SPAWNS.values():
		if spawn[1] == key:
			script = spawn[0]
	var e: Enemy = script.new()
	e.data = DB.enemies[key]
	e.position = pos
	level.get_node("Props").add_child(e)
	return e


## n 틱 진행
func step(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## cond 가 참이 될 때까지 한 틱씩 진행 (최대 max_ticks). 참이 됐으면 true
func wait_until(cond: Callable, max_ticks: int) -> bool:
	for i in max_ticks:
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())


func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func check_near(actual: float, expected: float, tolerance: float, label: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s (값 %.2f, 기대 %.2f±%.2f)" % [label, actual, expected, tolerance])
