class_name DebugOverlay
extends CanvasLayer
## 디버그 상태 표시 (디버그 빌드에서만 생성됨). 글꼴 문제를 피하려고 영문만 쓴다.

var _label: Label


func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.position = Vector2(2, 0)
	_label.add_theme_font_size_override(&"font_size", 8)
	_label.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.8))
	add_child(_label)


func _process(_delta: float) -> void:
	_label.text = "F1 hitbox:%s  F2 god:%s  F3/F4 section  tick:%d  fps:%d" % [
		"on" if Debug.show_hitboxes else "off",
		"on" if Debug.god_mode else "off",
		Game.tick,
		Engine.get_frames_per_second(),
	]
