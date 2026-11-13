class_name VolumeSliders
extends Control
## 소리 크기 슬라이더 묶음: 맨 위 "마스터"(전체 크기) + 소리 종류별 한 줄씩 (data/audio.tres 의 categories).
## 줄마다 이름 · 막대 · 숫자. 막대를 누르거나 끌기 · 휠 · (고른 줄에서) ←→ 로 조절한다.
## 값은 Settings 가 user://settings.json 에 저장하고, Audio 가 소리에 반영한다.

## 줄 하나 높이
const ROW_HEIGHT := 12.0
const NAME_WIDTH := 38.0
const TRACK_WIDTH := 60.0
const TRACK_HEIGHT := 4.0
const KNOB_SIZE := Vector2(4, 8)
const VALUE_WIDTH := 24.0
const COLOR_SELECTED := Color(0.97, 0.78, 0.35)
const COLOR_TRACK := Color(0.28, 0.26, 0.32)
const COLOR_FILL := Color(0.97, 0.78, 0.35)
const COLOR_FILL_IDLE := Color(0.7, 0.62, 0.45)
const COLOR_KNOB := Color(1, 1, 1)
const COLOR_RIM := Color(0.45, 0.42, 0.5)

## 고른 줄이 바뀌었을 때 (마우스를 올려도)
signal row_hovered(index: int)

## 줄마다 소리 종류 ("" = 전체)
var categories: Array[String] = []
## 고른 줄 (-1 = 없음). 고른 줄은 이름이 강조되고 ←→ 로 바뀐다
var selected: int = 0
## 방향키(↑↓ 고르기 · ←→ 조절)를 직접 받을지. 다른 메뉴 안에 넣으면 끄고 그 메뉴가 넘겨준다
var keyboard_enabled := false

var _names: Array[Label] = []
var _values: Array[Label] = []
var _dragging: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	categories.assign([""] + DB.audio.categories)
	size = Vector2(NAME_WIDTH + TRACK_WIDTH + VALUE_WIDTH + 8, ROW_HEIGHT * categories.size())
	custom_minimum_size = size
	for i in categories.size():
		var c := categories[i]
		var name_label := UiText.make_label("마스터" if c == "" else str(DB.audio.category_names.get(c, c)))
		name_label.position = Vector2(0, i * ROW_HEIGHT)
		name_label.size = Vector2(NAME_WIDTH, ROW_HEIGHT)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(name_label)
		_names.append(name_label)
		var value_label := UiText.make_label()
		value_label.position = Vector2(NAME_WIDTH + TRACK_WIDTH + 8, i * ROW_HEIGHT)
		value_label.size = Vector2(VALUE_WIDTH, ROW_HEIGHT)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(value_label)
		_values.append(value_label)
	Settings.volume_changed.connect(func(_v: float) -> void: refresh())
	refresh()


func row_count() -> int:
	return categories.size()


## 줄 i 의 막대 (이 컨트롤 안의 좌표)
func track_rect(i: int) -> Rect2:
	return Rect2(NAME_WIDTH + 2, i * ROW_HEIGHT + (ROW_HEIGHT - TRACK_HEIGHT) * 0.5, TRACK_WIDTH, TRACK_HEIGHT)


func value_of(i: int) -> float:
	return Audio.volume_of(categories[i])


func set_value(i: int, v: float) -> void:
	var before := value_of(i)
	Audio.set_volume_of(categories[i], v)
	if not is_equal_approx(before, value_of(i)):
		# 바뀐 크기를 바로 들려준다 (메뉴 소리 줄이면 메뉴 소리 크기로)
		Audio.play("ui_move")


## 고른 줄을 한 칸 올리거나 내린다
func step(direction: int, i: int = -1) -> void:
	if i < 0:
		i = selected
	if i >= 0 and i < categories.size():
		set_value(i, value_of(i) + direction * DB.audio.volume_step)


func select(i: int) -> void:
	selected = i
	refresh()


func refresh() -> void:
	for i in _names.size():
		var v := value_of(i)
		_values[i].text = "%d" % roundi(v * 100.0) if v > 0.0 else "끔"
		var color := COLOR_SELECTED if i == selected else Color.WHITE
		_names[i].add_theme_color_override(&"font_color", color)
		_values[i].add_theme_color_override(&"font_color", color)
	queue_redraw()


func _draw() -> void:
	for i in categories.size():
		var r := track_rect(i)
		var v := value_of(i)
		draw_rect(r.grow(1), COLOR_RIM)
		draw_rect(r, COLOR_TRACK)
		if v > 0.0:
			draw_rect(Rect2(r.position, Vector2(r.size.x * v, r.size.y)), COLOR_FILL if i == selected else COLOR_FILL_IDLE)
		var knob_x := roundf(r.position.x + r.size.x * v - KNOB_SIZE.x * 0.5)
		var knob := Rect2(Vector2(knob_x, r.get_center().y - KNOB_SIZE.y * 0.5), KNOB_SIZE)
		draw_rect(knob.grow(1), COLOR_RIM)
		draw_rect(knob, COLOR_KNOB)


func _row_at(pos: Vector2) -> int:
	var i := int(floor(pos.y / ROW_HEIGHT))
	return i if i >= 0 and i < categories.size() else -1


## 막대 위의 x → 값 (0~1)
func _value_at(i: int, x: float) -> float:
	var r := track_rect(i)
	return clampf((x - r.position.x) / r.size.x, 0.0, 1.0)


func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm != null:
		if _dragging >= 0:
			set_value(_dragging, _value_at(_dragging, mm.position.x))
		else:
			var hover := _row_at(mm.position)
			if hover >= 0 and hover != selected:
				select(hover)
				row_hovered.emit(hover)
		accept_event()
		return
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	var row := _row_at(mb.position)
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed and row >= 0:
			select(row)
			row_hovered.emit(row)
			_dragging = row
			set_value(row, _value_at(row, mb.position.x))
		elif not mb.pressed:
			_dragging = -1
	elif mb.pressed and row >= 0 and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		step(1, row)
	elif mb.pressed and row >= 0 and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		step(-1, row)
	else:
		return
	accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not keyboard_enabled or not is_visible_in_tree() or not event.is_pressed():
		return
	if event.is_action_pressed(&"ui_up", true):
		select(posmod(selected - 1, categories.size()))
	elif event.is_action_pressed(&"ui_down", true):
		select(posmod(selected + 1, categories.size()))
	elif event.is_action_pressed(&"ui_left", true):
		step(-1)
	elif event.is_action_pressed(&"ui_right", true):
		step(1)
	else:
		return
	get_viewport().set_input_as_handled()
