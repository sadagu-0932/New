class_name DebugOverlay
extends CanvasLayer
## 디버그 상태 표시 (디버그 빌드에서만 생성됨)

var _label: Label


func _ready() -> void:
	layer = 100
	_label = UiText.make_label()
	_label.position = Vector2(2, 12)
	_label.modulate.a = 0.7
	add_child(_label)


func _process(_delta: float) -> void:
	_label.text = "F1 히트박스:%s F2 무적:%s F3/F4 구간 틱:%d fps:%d" % [
		"on" if Debug.show_hitboxes else "off",
		"on" if Debug.god_mode else "off",
		Game.tick,
		Engine.get_frames_per_second(),
	]
