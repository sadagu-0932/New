extends Node
## 자동 테스트 실행기.
## 실행: godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn
## 실패가 있으면 종료 코드 1.

const SUITES: Array[Script] = [
	preload("res://tests/test_m1.gd"),
]


func _ready() -> void:
	var failures := 0
	var checks := 0
	for suite_script in SUITES:
		var suite: TestBase = suite_script.new()
		add_child(suite)
		await suite.run_all()
		failures += suite.failures
		checks += suite.checks
		suite.queue_free()
	print("")
	print("결과: %d개 검사 중 %d개 실패" % [checks, failures])
	PlayerInput.use_live_input()
	get_tree().quit(1 if failures > 0 else 0)
