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
	preload("res://tests/test_m6.gd"),
	preload("res://tests/test_m7.gd"),
	preload("res://tests/test_m8.gd"),
	preload("res://tests/test_m9.gd"),
	preload("res://tests/test_m10.gd"),
	preload("res://tests/test_s1.gd"),
	preload("res://tests/test_s2.gd"),
	preload("res://tests/test_s3.gd"),
	preload("res://tests/test_s4.gd"),
]
## 스토리판 묶음 (story_mode 를 켜고 돈다). 나머지는 공통 코드가 스피드런 규칙으로도 그대로 도는지 확인
const STORY_SUITES: Array[String] = ["res://tests/test_s1.gd", "res://tests/test_s2.gd", "res://tests/test_s3.gd", "res://tests/test_s4.gd"]


func _ready() -> void:
	# 테스트가 실제 저장 파일을 건드리지 않게
	StorySave.dir_override = "user://test_saves"
	StorySave.clear_all()
	var failures := 0
	var checks := 0
	for suite_script in SUITES:
		if not suite_script.can_instantiate():
			# 스크립트 오류로 못 불러온 묶음은 실패로 치고 넘어간다 (멈춰서 기다리지 않게)
			print("  FAIL  테스트 스크립트를 불러오지 못함: ", suite_script.resource_path)
			failures += 1
			checks += 1
			continue
		DB.game_config.story_mode = STORY_SUITES.has(suite_script.resource_path)
		var suite: TestBase = suite_script.new()
		add_child(suite)
		await suite.run_all()
		failures += suite.failures
		checks += suite.checks
		suite.queue_free()
		# 이전 묶음의 노드(레벨·플레이어)가 완전히 사라진 뒤 다음 묶음 시작
		await get_tree().physics_frame
		await get_tree().physics_frame
	print("")
	print("결과: %d개 검사 중 %d개 실패" % [checks, failures])
	PlayerInput.use_live_input()
	get_tree().quit(1 if failures > 0 else 0)
