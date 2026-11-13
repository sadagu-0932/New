class_name SettingsPanel
extends CanvasLayer
## 설정 창: 소리 슬라이더(마스터 + 소리 종류별) / 키 설정 / 돌아가기.
## 타이틀의 "설정", 일시정지 메뉴의 "설정" 에서 연다.
## ↑↓ 고르기 · 소리 줄에서 ←→ 로 크기 · Enter·클릭 고르기 · Esc 닫기
## 슬라이더는 마우스로 누르거나 끌기 · 휠로도 바꾼다. 값은 Settings 가 저장한다.

signal closed()

const COLOR_SELECTED := Color(0.97, 0.78, 0.35)
const COLOR_DISABLED := Color(1, 1, 1, 0.35)
const COLOR_BOX := Color(0.12, 0.11, 0.16)
const COLOR_BOX_RIM := Color(0.45, 0.42, 0.5)
## 창 상자 (320x180 화면 기준)
const BOX := Rect2(84, 12, 152, 140)
## 소리 슬라이더 묶음 위치 (상자 안)
const SLIDERS_POS := Vector2(95, 43)
## 소리 아래 메뉴 줄 (키 설정 · 돌아가기)
const MENU_ROWS: Array[String] = ["키 설정", "돌아가기"]
const MENU_ROW_HEIGHT := 14.0

var is_open: bool = false
## 고른 줄: 0 ~ 소리 줄 수-1 = 슬라이더, 그 뒤 키 설정 · 돌아가기
var selected: int = 0
var key_panel: KeyBindPanel
var sliders: VolumeSliders

var _root: Control
var _menu_labels: Array[Label] = []


func is_showing() -> bool:
	return is_open


## base_layer: 이 창을 연 화면의 층 (그 위에 뜬다)
func _init(base_layer: int = 95) -> void:
	layer = base_layer + 1


func _ready() -> void:
	add_to_group(Crosshair.POINTER_GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 아래 화면의 메뉴가 클릭되지 않게 막는다
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var rim := ColorRect.new()
	rim.color = COLOR_BOX_RIM
	rim.position = BOX.position - Vector2.ONE
	rim.size = BOX.size + Vector2(2, 2)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rim)
	var box := ColorRect.new()
	box.color = COLOR_BOX
	box.position = BOX.position
	box.size = BOX.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	var title := UiText.make_label("설정")
	title.position = Vector2(BOX.position.x, BOX.position.y + 3)
	title.size = Vector2(BOX.size.x, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)
	var sound := UiText.make_label("소리")
	sound.position = Vector2(SLIDERS_POS.x, BOX.position.y + 17)
	sound.size = Vector2(60, 12)
	sound.modulate = Color(1, 1, 1, 0.6)
	_root.add_child(sound)
	sliders = VolumeSliders.new()
	sliders.position = SLIDERS_POS
	sliders.row_hovered.connect(_select)
	_root.add_child(sliders)
	var menu_top := SLIDERS_POS.y + sliders.size.y + 6.0
	for i in MENU_ROWS.size():
		var label := UiText.make_label(MENU_ROWS[i])
		label.position = Vector2(BOX.position.x + 6, menu_top + i * MENU_ROW_HEIGHT)
		label.size = Vector2(BOX.size.x - 12, MENU_ROW_HEIGHT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		var row := sliders.row_count() + i
		label.gui_input.connect(_on_row_input.bind(row))
		label.mouse_entered.connect(_select.bind(row))
		_root.add_child(label)
		_menu_labels.append(label)
	var help := UiText.make_label("↑↓ 고르기 · ←→ 소리 크기 · Esc 닫기")
	help.position = Vector2(0, BOX.end.y + 4)
	help.size = Vector2(320, 12)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.modulate = Color(1, 1, 1, 0.7)
	_root.add_child(help)
	key_panel = KeyBindPanel.new()
	add_child(key_panel)
	key_panel.layer = layer + 1
	_root.visible = false


## 키 설정 줄 번호
func row_keys() -> int:
	return sliders.row_count()


## 돌아가기 줄 번호
func row_back() -> int:
	return sliders.row_count() + 1


func row_count() -> int:
	return sliders.row_count() + MENU_ROWS.size()


func open() -> void:
	is_open = true
	_root.visible = true
	selected = 0
	_refresh()


func close() -> void:
	if not is_open:
		return
	is_open = false
	key_panel.close()
	_root.visible = false
	closed.emit()


## 키 설정은 키보드·마우스 기기에서만 (터치 버튼 위치는 일시정지 → [배치])
func _is_enabled(i: int) -> bool:
	return i != row_keys() or not TouchControls.is_enabled()


func _refresh() -> void:
	sliders.select(selected if selected < sliders.row_count() else -1)
	for i in _menu_labels.size():
		var row := sliders.row_count() + i
		var color := Color.WHITE
		if not _is_enabled(row):
			color = COLOR_DISABLED
		elif row == selected:
			color = COLOR_SELECTED
		_menu_labels[i].add_theme_color_override(&"font_color", color)
		_menu_labels[i].text = ("> %s <" % MENU_ROWS[i]) if row == selected else MENU_ROWS[i]


func _select(i: int) -> void:
	if not is_open or key_panel.is_open or i == selected or not _is_enabled(i):
		return
	selected = i
	Audio.play("ui_move")
	_refresh()


func _move(step: int) -> void:
	var i := selected
	for _n in row_count():
		i = posmod(i + step, row_count())
		if _is_enabled(i):
			break
	_select(i)


func activate(i: int) -> void:
	if not is_open or not _is_enabled(i):
		return
	if i == row_keys():
		Audio.play("ui_confirm")
		key_panel.open()
	elif i == row_back():
		Audio.play("ui_confirm")
		close()


func _input(event: InputEvent) -> void:
	# 마우스는 슬라이더·줄이 직접 받는다
	if not is_open or key_panel.is_open or event is InputEventMouse:
		return
	# 열려 있는 동안 아래 화면(일시정지 해제 등)이 키를 받지 않게
	get_viewport().set_input_as_handled()
	var on_slider := selected < sliders.row_count()
	if event.is_action_pressed(&"pause") and not event.is_echo():
		Audio.play("ui_confirm")
		close()
	elif event.is_action_pressed(&"ui_up", true) or (event.is_action_pressed(&"move_up") and not event.is_echo()):
		_move(-1)
	elif event.is_action_pressed(&"ui_down", true) or (event.is_action_pressed(&"move_down") and not event.is_echo()):
		_move(1)
	elif on_slider and (event.is_action_pressed(&"ui_left", true) or event.is_action_pressed(&"move_left", true)):
		sliders.step(-1, selected)
	elif on_slider and (event.is_action_pressed(&"ui_right", true) or event.is_action_pressed(&"move_right", true)):
		sliders.step(1, selected)
	elif event.is_action_released(&"menu_confirm"):
		activate(selected)


func _on_row_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or key_panel.is_open:
		return
	if mb.pressed:
		_select(i)
	else:
		activate(i)
