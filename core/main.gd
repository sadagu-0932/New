extends Node
## 진입점. 튜토리얼 런을 바로 시작한다 (시작 화면 없음, 스킬은 출발 전 Tab 으로 설정).
## TODO(M7): 기록 화면 흐름, TODO(M9): 타이틀·어트랙트 모드


func _ready() -> void:
	var run := RunController.new(RunSetup.from_config(DB.game_config))
	add_child(run)
	add_child(Hud.new())
	add_child(HintDisplay.new())
	add_child(BossBar.new())
	add_child(DialoguePlayer.new())
	add_child(Crosshair.new())
	add_child(PauseOverlay.new())
	add_child(SkillPanel.new(run))
	add_child(RunTimer.new())
	add_child(ResultScreen.new(run))
	if Debug.enabled:
		add_child(DebugOverlay.new())
