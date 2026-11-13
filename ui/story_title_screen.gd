class_name StoryTitleScreen
extends CanvasLayer
## 스토리판 타이틀: 새 게임 / 이어하기 / 설정 / 종료.
## ↑↓(또는 W·S)로 고르고 Enter·Space·클릭으로 확정. 스피드런 기능(순위·어트랙트 모드)은 없다.

signal new_game_requested()
signal continue_requested()

enum Item { NEW_GAME, CONTINUE, SETTINGS, QUIT }

const ITEMS: Array[String] = ["새 게임", "이어하기", "설정", "종료"]
const ROW_HEIGHT := 16.0
const TOP := 76.0
const COLOR_SELECTED := Color(0.97, 0.78, 0.35)
const COLOR_DISABLED := Color(1, 1, 1, 0.3)

var selected: int = 0
## 이어할 저장이 있는지 (없으면 이어하기를 고를 수 없다). StoryMain 이 타이틀을 띄울 때 채운다
var can_continue: bool = false
var key_panel: KeyBindPanel
## 소리 크기 다이얼 (오른쪽 아래)
var volume_dial: VolumeDial

var _root: Control
var _labels: Array[Label] = []


func _ready() -> void:
	layer = 99
	add_to_group(Crosshair.POINTER_GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.07, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var title := UiText.make_label(ProjectSettings.get_setting("application/config/name", ""), UiText.SIZE_LARGE)
	title.position = Vector2(0, 24)
	title.size = Vector2(320, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)
	var sub := UiText.make_label(DB.story.title_subtitle)
	sub.position = Vector2(0, 50)
	sub.size = Vector2(320, 12)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate.a = 0.7
	_root.add_child(sub)
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
	volume_dial.position = Vector2(272, 126)
	_root.add_child(volume_dial)
	# 타이틀(99) 위에 뜨도록 층을 올린다
	key_panel = KeyBindPanel.new()
	add_child(key_panel)
	key_panel.layer = layer + 1
	_refresh()


func _process(_delta: float) -> void:
	if volume_dial != null:
		volume_dial.visible = not key_panel.is_open


func set_visible_screen(value: bool) -> void:
	_root.visible = value
	if value:
		selected = Item.CONTINUE if can_continue else Item.NEW_GAME
		_refresh()
	else:
		key_panel.close()


func is_showing() -> bool:
	return _root.visible


func _is_enabled(i: int) -> bool:
	return i != Item.CONTINUE or can_continue


func _select(i: int) -> void:
	if not _root.visible or key_panel.is_open or not _is_enabled(i) or i == selected:
		return
	selected = i
	Audio.play("ui_move")
	_refresh()


## 고를 수 없는 항목은 건너뛰며 위아래로 옮긴다
func _move(step: int) -> void:
	var i := selected
	for _n in ITEMS.size():
		i = posmod(i + step, ITEMS.size())
		if _is_enabled(i):
			break
	_select(i)


func _refresh() -> void:
	for i in _labels.size():
		var color := Color.WHITE
		if not _is_enabled(i):
			color = COLOR_DISABLED
		elif i == selected:
			color = COLOR_SELECTED
		_labels[i].add_theme_color_override(&"font_color", color)
		_labels[i].text = ("> %s <" % ITEMS[i]) if i == selected else ITEMS[i]


func activate(i: int) -> void:
	if not _is_enabled(i):
		return
	Audio.play("ui_confirm")
	match i:
		Item.NEW_GAME:
			new_game_requested.emit()
		Item.CONTINUE:
			continue_requested.emit()
		Item.SETTINGS:
			# 터치 기기의 버튼 위치 바꾸기는 게임 중 일시정지 → [배치] 에서 한다
			if not TouchControls.is_enabled():
				key_panel.open()
		Item.QUIT:
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or key_panel.is_open or event.is_echo():
		return
	var handled := true
	if event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
		_move(-1)
	elif event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
		_move(1)
	elif event.is_action_released(&"menu_confirm") or event.is_action_released(&"dodge"):
		# 뗄 때 확정 → 확정 키가 곧바로 게임 입력(회피)으로 이어지지 않게
		activate(selected)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _on_item_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or key_panel.is_open:
		return
	# 누를 때 고르고, 뗄 때 확정 (누른 채로 시작해 사격으로 이어지지 않게)
	if mb.pressed:
		_select(i)
	else:
		activate(i)
