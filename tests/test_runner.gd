extends Node
## 자동 테스트 실행기.
## 실행: godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn
## 실패가 있으면 종료 코드 1.

const SUITES: Array[Script] = [
	preload("res://tests/test_m1.gd"),
	preload("res://tests/test_m2.gd"),
	preload("res://tests/test_m3.gd"),
	preload("res://tests/test_m4.gd"),
	preload("res://tests/test_m5.gd"),
]


func _ready() -> void:
	var failures := 0
	var checks := 0
	for suite_script in SUITES:
		if not suite_script.can_instantiate():
			# 스크립트 오류로 못 불러온 묶음은 실패로 치고 넘어간다 (멈춰서 기다리지 않게)
			print("  FAIL  테스트 스크립트를 불러오지 못함: ", suite_script.resource_path)
			failures += 1
			checks += 1
			continue
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
