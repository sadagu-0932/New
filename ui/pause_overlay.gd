class_name PauseOverlay
extends CanvasLayer
## 일시정지 화면 (어둡게 + 글자). TODO: 메뉴(타이틀로 등)

var _root: Control


## 열려 있는지 (Crosshair 가 포인터로 바꿀 때 사용)
func is_showing() -> bool:
	return _root != null and _root.visible


func _ready() -> void:
	layer = 95
	add_to_group(Crosshair.POINTER_GROUP)
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
	var label := UiText.make_label("일시정지\n\nEsc 계속하기 · R 길게 눌러 처음부터")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(label)
	_root.visible = false
	Events.pause_changed.connect(func(p: bool) -> void: _root.visible = p)
