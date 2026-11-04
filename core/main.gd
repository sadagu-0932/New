extends Node
## 진입점. 지금은 설정의 시작 맵으로 런을 바로 시작한다.
## TODO(M5·M7): 타이틀 → 스킬 선택 → 런 → 기록 화면 흐름


func _ready() -> void:
	add_child(RunController.new(RunSetup.from_config(DB.game_config)))
	add_child(Hud.new())
	add_child(HintDisplay.new())
	add_child(DialoguePlayer.new())
	add_child(Crosshair.new())
	add_child(PauseOverlay.new())
	if Debug.enabled:
		add_child(DebugOverlay.new())
