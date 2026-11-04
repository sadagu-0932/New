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


## n 틱 진행
func step(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func check_near(actual: float, expected: float, tolerance: float, label: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s (값 %.2f, 기대 %.2f±%.2f)" % [label, actual, expected, tolerance])
