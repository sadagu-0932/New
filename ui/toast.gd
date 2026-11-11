class_name Toast
extends CanvasLayer
## 화면 오른쪽 위에 잠깐 뜨는 알림 글 (저장됨 등). Events.toast 로 띄운다. 게임을 멈추지 않는다.

var _label: Label
var _left: float = 0.0


func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = UiText.make_label()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.position = Vector2(120, 4)
	_label.size = Vector2(196, 12)
	_label.modulate.a = 0.0
	add_child(_label)
	Events.toast.connect(show_text)


func show_text(text: String) -> void:
	_label.text = text
	_left = DB.save.toast_seconds
	_label.modulate.a = 1.0


func current_text() -> String:
	return _label.text if _left > 0.0 else ""


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
	else:
		_label.modulate.a = move_toward(_label.modulate.a, 0.0, delta * 4.0)
