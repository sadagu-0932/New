extends Node
## 진입점. 지금(M1)은 테스트 방을 바로 띄운다.
## TODO(M5·M7): 타이틀 → 스킬 선택 → 런 흐름으로 교체


func _ready() -> void:
	var level := Level.new()
	level.map_path = DB.game_config.start_map_path
	add_child(level)
	add_child(Crosshair.new())
	if Debug.enabled:
		add_child(DebugOverlay.new())
