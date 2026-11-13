class_name VolumeDial
extends Control
## 소리 크기 다이얼 (일시정지 화면·타이틀에 놓는다).
## 손잡이를 잡고 돌리기(끌기) · 마우스 휠 · 방향키 ←→ 로 조절한다.
## 값은 Settings 가 user://settings.json 에 저장하고, Audio 가 전체 소리 크기에 반영한다.
## 단계·기본값은 data/audio.tres (volume_step, volume_default)

## 다이얼이 도는 범위 (위쪽 0도 기준 왼쪽 끝 ~ 오른쪽 끝)
const SWEEP_DEG := 135.0
const RADIUS := 11.0
const COLOR_BODY := Color(0.16, 0.15, 0.2)
const COLOR_RIM := Color(0.45, 0.42, 0.5)
const COLOR_TRACK := Color(0.28, 0.26, 0.32)
const COLOR_FILL := Color(0.97, 0.78, 0.35)
const COLOR_POINTER := Color(1, 1, 1)
const COLOR_MUTED := Color(0.6, 0.3, 0.3)

## 방향키로도 조절할지 (메뉴 위·아래 이동과 겹치지 않는 ←→ 만 쓴다)
var keyboard_enabled := true

var _dragging := false
var _label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(40, 46)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = UiText.make_label()
	_label.position = Vector2(0, 30)
	_label.size = Vector2(size.x, 12)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	Settings.volume_changed.connect(func(_v: float) -> void: _refresh())
	_refresh()


func _center() -> Vector2:
	return Vector2(size.x * 0.5, 15)


## 값(0~1) → 각도 (라디안, 위쪽이 0)
static func value_to_angle(v: float) -> float:
	return deg_to_rad(lerpf(-SWEEP_DEG, SWEEP_DEG, clampf(v, 0.0, 1.0)))


## 다이얼 가운데에서 본 점 → 값(0~1). 아래쪽 빈 곳은 가까운 끝으로
static func point_to_value(offset: Vector2) -> float:
	# 위쪽 0도, 시계 방향 +
	var deg := rad_to_deg(atan2(offset.x, -offset.y))
	return clampf(inverse_lerp(-SWEEP_DEG, SWEEP_DEG, deg), 0.0, 1.0)


func _refresh() -> void:
	var v := Audio.volume()
	_label.text = "소리 %d" % roundi(v * 100.0) if v > 0.0 else "소리 끔"
	queue_redraw()


func _draw() -> void:
	var c := _center()
	var v := Audio.volume()
	var start := value_to_angle(0.0) - PI * 0.5
	var stop := value_to_angle(1.0) - PI * 0.5
	var now := value_to_angle(v) - PI * 0.5
	# 바깥 눈금 길 (전체 → 채워진 만큼)
	draw_arc(c, RADIUS + 3, start, stop, 32, COLOR_TRACK, 2.0)
	if v > 0.0:
		draw_arc(c, RADIUS + 3, start, now, 32, COLOR_FILL, 2.0)
	# 눈금 (양 끝 + 가운데)
	for t: float in [0.0, 0.5, 1.0]:
		var a := value_to_angle(t) - PI * 0.5
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * (RADIUS + 5), c + dir * (RADIUS + 7), COLOR_RIM, 1.0)
	# 손잡이 몸통
	draw_circle(c, RADIUS, COLOR_RIM)
	draw_circle(c, RADIUS - 1.5, COLOR_BODY)
	# 가리키는 선
	var p := Vector2(cos(now), sin(now))
	draw_line(c + p * 3.0, c + p * (RADIUS - 2.5), COLOR_MUTED if v <= 0.0 else COLOR_POINTER, 2.0)
	draw_circle(c, 1.5, COLOR_RIM)


func _set_value(v: float) -> void:
	var before := Audio.volume()
	Audio.set_volume(v)
	if not is_equal_approx(before, Audio.volume()):
		# 바뀐 크기를 바로 들려준다
		Audio.play("ui_move")


func step(direction: int) -> void:
	_set_value(Audio.volume() + direction * DB.audio.volume_step)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			step(1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			step(-1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				_set_value(point_to_value(mb.position - _center()))
		else:
			return
		accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _dragging:
		_set_value(point_to_value(mm.position - _center()))
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not keyboard_enabled or not is_visible_in_tree() or not event.is_pressed():
		return
	if event.is_action_pressed(&"ui_left", true):
		step(-1)
	elif event.is_action_pressed(&"ui_right", true):
		step(1)
	else:
		return
	get_viewport().set_input_as_handled()
