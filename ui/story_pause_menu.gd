class_name StoryPauseMenu
extends CanvasLayer
## 스토리판 일시정지 메뉴: 계속하기 / 저장 / 불러오기 / 키 설정 / 타이틀로.
## Esc 로 열고 닫는다 (RunController 가 일시정지를 관리, 여기서는 화면과 항목만).
# TODO(안드로이드 추가 때): 터치 버튼 위치 바꾸기([배치]) 항목

signal resume_requested()
signal save_requested()
signal load_requested()
signal title_requested()

enum Item { RESUME, SAVE, LOAD, KEYS, TITLE }

const ITEMS: Array[String] = ["계속하기", "저장", "불러오기", "키 설정", "타이틀로"]
const ROW_HEIGHT := 16.0
const TOP := 56.0
const COLOR_SELECTED := Color(0.97, 0.78, 0.35)

var selected: int = 0
var key_panel: KeyBindPanel
## 소리 크기 다이얼 (오른쪽)
var volume_dial: VolumeDial

var _root: Control
var _labels: Array[Label] = []


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
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var title := UiText.make_label("일시정지")
	title.position = Vector2(0, 30)
	title.size = Vector2(320, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)
	for i in ITEMS.size():
		var label := UiText.make_label(ITEMS[i])
		label.position = Vector2(110, TOP + i * ROW_HEIGHT)
		label.size = Vector2(100, ROW_HEIGHT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.gui_input.connect(_on_item_input.bind(i))
		label.mouse_entered.connect(_select.bind(i))
		_root.add_child(label)
		_labels.append(label)
	volume_dial = VolumeDial.new()
	volume_dial.position = Vector2(236, 70)
	_root.add_child(volume_dial)
	_root.visible = false
	key_panel = KeyBindPanel.new()
	add_child(key_panel)
	Events.pause_changed.connect(_on_pause_changed)


func _process(_delta: float) -> void:
	if volume_dial != null:
		volume_dial.visible = not key_panel.is_open


func _on_pause_changed(paused: bool) -> void:
	_root.visible = paused
	if paused:
		selected = Item.RESUME
		_refresh()
	else:
		key_panel.close()


func _refresh() -> void:
	for i in _labels.size():
		_labels[i].add_theme_color_override(&"font_color", COLOR_SELECTED if i == selected else Color.WHITE)
		_labels[i].text = ("> %s <" % ITEMS[i]) if i == selected else ITEMS[i]


func _select(i: int) -> void:
	if not _root.visible or key_panel.is_open or i == selected:
		return
	selected = i
	Audio.play("ui_move")
	_refresh()


func activate(i: int) -> void:
	if not _root.visible:
		return
	Audio.play("ui_confirm")
	match i:
		Item.RESUME:
			resume_requested.emit()
		Item.SAVE:
			save_requested.emit()
		Item.LOAD:
			load_requested.emit()
		Item.KEYS:
			key_panel.open()
		Item.TITLE:
			title_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or key_panel.is_open or event.is_echo():
		return
	var handled := true
	if event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
		_select(posmod(selected - 1, ITEMS.size()))
	elif event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
		_select(posmod(selected + 1, ITEMS.size()))
	elif event.is_action_released(&"menu_confirm") or event.is_action_released(&"dodge"):
		activate(selected)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _on_item_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or key_panel.is_open:
		return
	if mb.pressed:
		_select(i)
	elif i == selected:
		activate(i)
