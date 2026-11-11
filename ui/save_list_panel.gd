class_name SaveListPanel
extends CanvasLayer
## 저장 목록 (불러오기). 최신이 맨 위, 가장 오래된 것이 맨 아래.
## ↑↓(W·S)·마우스로 고르고 Enter·Space·클릭으로 불러온다. Esc 닫기.

signal save_chosen(save: Dictionary)

const ROW_HEIGHT := 16.0
const TOP := 34.0
const COLOR_SELECTED := Color(0.97, 0.78, 0.35)

var is_open: bool = false
var selected: int = 0
var saves: Array[Dictionary] = []

var _root: Control
var _rows: Array[Label] = []
var _empty: Label


func is_showing() -> bool:
	return is_open


func _ready() -> void:
	# 타이틀(99) 위에도 떠야 한다
	layer = 101
	add_to_group(Crosshair.POINTER_GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.07, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var title := UiText.make_label("불러오기")
	title.position = Vector2(0, 10)
	title.size = Vector2(320, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)
	for i in DB.save.auto_slots + 1:
		var row := UiText.make_label()
		row.position = Vector2(30, TOP + i * ROW_HEIGHT)
		row.size = Vector2(260, ROW_HEIGHT)
		row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.gui_input.connect(_on_row_input.bind(i))
		row.mouse_entered.connect(_select.bind(i))
		_root.add_child(row)
		_rows.append(row)
	_empty = UiText.make_label(DB.save.text_no_saves)
	_empty.position = Vector2(0, 80)
	_empty.size = Vector2(320, 12)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_empty)
	var help := UiText.make_label("↑↓ 고르기 · Enter 불러오기 · Esc 닫기")
	help.position = Vector2(0, 160)
	help.size = Vector2(320, 12)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.modulate.a = 0.7
	_root.add_child(help)
	_root.visible = false


func open() -> void:
	saves = StorySave.list()
	selected = 0
	is_open = true
	_root.visible = true
	_refresh()


func close() -> void:
	is_open = false
	_root.visible = false


## 목록 한 줄: [종류] 날짜 시간 · 지역 · 체력
static func row_text(save: Dictionary) -> String:
	var state: Dictionary = save.get("state", {})
	var story: Dictionary = state.get("story", {})
	var area := String(story.get("area", ""))
	return "[%s] %s  %s  체력 %d" % [DB.save.kind_names.get(save.get("kind", ""), "?"), save.get("saved_at", ""),
		DB.area(area).display_name if DB.area(area) != null else area, int(state.get("hp", 0))]


func _refresh() -> void:
	_empty.visible = saves.is_empty()
	for i in _rows.size():
		_rows[i].visible = i < saves.size()
		if i >= saves.size():
			continue
		_rows[i].text = ("> " if i == selected else "  ") + row_text(saves[i])
		_rows[i].add_theme_color_override(&"font_color", COLOR_SELECTED if i == selected else Color.WHITE)


func _select(i: int) -> void:
	if not is_open or i >= saves.size() or i == selected:
		return
	selected = i
	Audio.play("ui_move")
	_refresh()


func confirm() -> void:
	if not is_open or selected >= saves.size():
		return
	var save := saves[selected]
	Audio.play("ui_confirm")
	close()
	save_chosen.emit(save)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or event.is_echo():
		return
	if event.is_action_pressed(&"pause"):
		close()
	elif event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
		_select(posmod(selected - 1, maxi(saves.size(), 1)))
	elif event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
		_select(posmod(selected + 1, maxi(saves.size(), 1)))
	elif event.is_action_released(&"menu_confirm") or event.is_action_released(&"dodge"):
		confirm()
	# 열려 있는 동안에는 아래 화면으로 입력을 넘기지 않는다
	get_viewport().set_input_as_handled()


func _on_row_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_select(i)
	elif i == selected:
		confirm()
