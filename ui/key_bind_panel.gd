class_name KeyBindPanel
extends CanvasLayer
## 키 설정 창 (PC). 일시정지 화면에서 K 로 연다.
## ↑↓ 또는 마우스로 고르고, Enter·클릭 후 새 키(또는 마우스 버튼)를 누르면 바뀐다.
## 다른 동작과 키가 겹치면 바꾸지 않고 그대로 두되, 겹친 키들을 빨간 [대괄호]로 표시해 알려준다.
## Backspace 는 전부 기본값으로. Esc 닫기

const ROW_HEIGHT := 12.0
const TOP := 18.0
const COLOR_SELECTED := Color(0.97, 0.78, 0.35)
## 겹치는 키 표시 색
const COLOR_CONFLICT := Color(0.9, 0.25, 0.3)

var is_open: bool = false
var selected: int = 0
## 새 키를 기다리는 중
var listening: bool = false

var _root: Control
var _names: Array[Label] = []
var _keys: Array[Label] = []
var _help: Label


func is_showing() -> bool:
	return is_open


func _ready() -> void:
	# 일시정지 화면(95) 위
	layer = 97
	add_to_group(Crosshair.POINTER_GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.07, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var title := UiText.make_label("키 설정")
	title.position = Vector2(0, 4)
	title.size = Vector2(320, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)
	for i in Settings.REBINDABLE.size():
		var name_label := UiText.make_label(Settings.REBINDABLE[i][1])
		name_label.position = Vector2(84, TOP + i * ROW_HEIGHT)
		name_label.size = Vector2(80, 12)
		_root.add_child(name_label)
		_names.append(name_label)
		var key_label := UiText.make_label()
		key_label.position = Vector2(170, TOP + i * ROW_HEIGHT)
		key_label.size = Vector2(70, 12)
		_root.add_child(key_label)
		_keys.append(key_label)
	_help = UiText.make_label()
	_help.position = Vector2(0, 165)
	_help.size = Vector2(320, 12)
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help.modulate = Color(1, 1, 1, 0.7)
	_root.add_child(_help)
	_root.visible = false


func open() -> void:
	is_open = true
	listening = false
	_root.visible = true
	_refresh()


func close() -> void:
	is_open = false
	listening = false
	_root.visible = false


func _refresh() -> void:
	for i in _names.size():
		var action: StringName = Settings.REBINDABLE[i][0]
		var color := COLOR_SELECTED if i == selected else Color.WHITE
		_names[i].add_theme_color_override(&"font_color", color)
		if listening and i == selected:
			_keys[i].text = "누를 키 …"
		elif Settings.is_conflicting(action):
			# 다른 동작과 겹치는 키: 빨간 [대괄호]
			_keys[i].text = "[%s]" % Settings.key_name(action)
			color = COLOR_CONFLICT
		else:
			_keys[i].text = Settings.key_name(action)
		_keys[i].add_theme_color_override(&"font_color", color)
	var conflict := Settings.has_conflicts() and not listening
	_help.add_theme_color_override(&"font_color", COLOR_CONFLICT if conflict else Color.WHITE)
	if listening:
		_help.text = "새 키나 마우스 버튼을 누르세요 · Esc 취소"
	elif conflict:
		_help.text = "[빨간 키]는 서로 겹쳐요 · Enter/클릭으로 다시 정하기 · Esc 닫기"
	else:
		_help.text = "↑↓ 고르기 · Enter/클릭 바꾸기 · Backspace 기본값 · Esc 닫기"


## 마우스가 가리키는 줄 (-1 = 없음)
func _row_at(pos: Vector2) -> int:
	var i := int(floor((pos.y - TOP) / ROW_HEIGHT))
	if i >= 0 and i < _names.size() and pos.x >= 80.0 and pos.x <= 244.0:
		return i
	return -1


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseMotion:
		return
	# 열려 있는 동안 다른 화면(일시정지 해제 등)이 입력을 받지 않게
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo():
		return
	if listening:
		if event.is_action(&"pause"):
			listening = false
		else:
			var binding := Settings.binding_from_event(event)
			if binding.is_empty():
				return
			Settings.rebind(Settings.REBINDABLE[selected][0], binding)
			listening = false
		_refresh()
		return
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		var row := _row_at(mb.position)
		if row >= 0:
			selected = row
			listening = true
	elif event.is_action(&"pause"):
		close()
		return
	elif event.is_action(&"menu_confirm"):
		listening = true
	elif event.is_action(&"ui_up"):
		selected = posmod(selected - 1, _names.size())
	elif event.is_action(&"ui_down"):
		selected = posmod(selected + 1, _names.size())
	elif event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_BACKSPACE:
		Settings.reset_keys()
	_refresh()
