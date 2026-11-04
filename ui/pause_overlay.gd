class_name PauseOverlay
extends CanvasLayer
## 일시정지 화면 (어둡게 + 글자). 한글 픽셀 폰트가 정해지기 전까지 영문 표시.
## TODO(M4 이후): 한글 문구·메뉴

var _root: Control


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var label := Label.new()
	label.text = "PAUSED\nEsc: resume   R(hold): restart"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 8)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(label)
	_root.visible = false
	Events.pause_changed.connect(func(p: bool) -> void: _root.visible = p)
