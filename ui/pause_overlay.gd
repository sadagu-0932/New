class_name PauseOverlay
extends CanvasLayer
## 일시정지 화면 (어둡게 + 글자). 여기서 설정을 연다:
## PC 는 K → 키 설정 창, 터치 기기는 [배치] 버튼 → 버튼 위치 바꾸기

const TEXT := "일시정지\n\nEsc 계속하기 · R 길게 눌러 처음부터\nK 키 설정"

var key_panel: KeyBindPanel
var _root: Control
var _label: Label


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
	_label = UiText.make_label(UiText.for_device(TEXT))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_label)
	_root.visible = false
	key_panel = KeyBindPanel.new()
	add_child(key_panel)
	Events.pause_changed.connect(_on_pause_changed)
	Settings.changed.connect(func() -> void: _label.text = UiText.for_device(TEXT))


func _process(_delta: float) -> void:
	# 버튼 위치를 바꾸는 동안에는 일시정지 글자를 숨긴다 (버튼·안내와 겹치지 않게)
	_label.visible = not (TouchControls.instance != null and TouchControls.instance.edit_mode)


func _on_pause_changed(paused: bool) -> void:
	_root.visible = paused
	if not paused:
		key_panel.close()
		if TouchControls.instance != null:
			TouchControls.instance.set_edit_mode(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or not event.is_action_pressed(&"open_settings") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if TouchControls.instance != null:
		TouchControls.instance.set_edit_mode(true)
	else:
		key_panel.open()
