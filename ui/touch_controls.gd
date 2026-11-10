class_name TouchControls
extends CanvasLayer
## 안드로이드 터치 조작 (APK 전용).
## 내보내기 설정의 기능 태그 "touch_controls" 가 있을 때만 켜진다 → PC·웹 버전에는 나오지 않는다.
##
## - 왼쪽 조이스틱: 이동 (메뉴에서는 방향 선택)
## - 오른쪽 조이스틱: 조준, 끝까지 밀면 사격
## - 둥근 버튼: 근접(=패링), 회피, 스킬, 사용
## - 위쪽 작은 버튼: 일시정지, 재시작(누르고 있기), 스킬 설정
## - 메뉴가 열려 있으면: 확인, 뒤로
##
## 버튼은 키보드와 똑같은 Input Map 액션을 눌러 준다 → 게임 로직·리플레이는 키보드와 같은 길로 간다.
## 조준만은 마우스 위치 대신 aim_world() 를 LiveInputSource 가 읽는다.

const FEATURE := "touch_controls"
const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
const ACTION_BUTTONS: Array = [[&"melee", "근접"], [&"dodge", "회피"], [&"skill", "스킬"], [&"interact", "사용"]]
const TOP_BUTTONS: Array = [[&"pause", "멈춤"], [&"restart", "재시작"], [&"skill_menu", "스킬"]]
const MENU_BUTTONS: Array = [[&"menu_confirm", "확인"], [&"pause", "뒤로"]]

## 지금 켜진 터치 조작 (없으면 null)
static var instance: TouchControls
## 테스트용: 기능 태그 없이도 켠다
static var force_enabled: bool = false

## 마지막 조준 방향 (조준 조이스틱을 놓아도 유지)
var aim_dir: Vector2 = Vector2.RIGHT
## 이동 조이스틱 값 (-1~1)
var move_vec: Vector2 = Vector2.ZERO
## 조준 조이스틱 값 (-1~1)
var aim_vec: Vector2 = Vector2.ZERO

var _data: TouchData
var _move_stick: Dictionary
var _aim_stick: Dictionary
## 버튼: { "action", "pos", "radius", "node", "group" }
var _buttons: Array[Dictionary] = []
## 손가락 번호 → 잡고 있는 것 ("move" / "aim" / 버튼 Dictionary)
var _touches: Dictionary = {}
## 메뉴 방향 입력을 이미 보낸 방향 (계속 밀고 있어도 한 번만)
var _menu_dirs_sent: Dictionary = {}
var _firing: bool = false


static func is_enabled() -> bool:
	return force_enabled or OS.has_feature(FEATURE)


func _ready() -> void:
	instance = self
	_data = DB.touch
	# 모든 화면 위, 커서(110) 아래
	layer = 105
	process_mode = Node.PROCESS_MODE_ALWAYS
	_strip_mouse_buttons()
	_move_stick = _make_stick(_data.move_stick_center)
	_aim_stick = _make_stick(_data.aim_stick_center)
	var round_tex := DB.theme.load_texture("touch_button")
	var small_tex := DB.theme.load_texture("touch_button_small")
	for i in ACTION_BUTTONS.size():
		_add_button(ACTION_BUTTONS[i], _data.action_button_positions[i], round_tex, _data.action_button_radius, "action")
	for i in TOP_BUTTONS.size():
		_add_button(TOP_BUTTONS[i], _data.top_button_positions[i], small_tex, 0.0, "top")
	for i in MENU_BUTTONS.size():
		_add_button(MENU_BUTTONS[i], _data.menu_button_positions[i], small_tex, 0.0, "menu")


func _exit_tree() -> void:
	_release_all()
	if instance == self:
		instance = null


## 터치가 마우스 클릭으로도 들어오므로(타이틀·스킬 카드용) 사격·근접에서는 마우스 버튼을 뺀다
## → 조이스틱·버튼을 누를 때 사격·근접이 같이 나가지 않는다
func _strip_mouse_buttons() -> void:
	for action: StringName in [&"shoot", &"melee"]:
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventMouseButton:
				InputMap.action_erase_event(action, ev)


func _make_stick(center: Vector2) -> Dictionary:
	var base := Sprite2D.new()
	base.texture = DB.theme.load_texture("touch_stick_base")
	base.position = center
	add_child(base)
	var knob := Sprite2D.new()
	knob.texture = DB.theme.load_texture("touch_stick_knob")
	knob.position = center
	add_child(knob)
	return {"center": center, "base": base, "knob": knob, "value": Vector2.ZERO}


func _add_button(def: Array, pos: Vector2, tex: Texture2D, radius: float, group: String) -> void:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.position = pos
	add_child(spr)
	var label := UiText.make_label(def[1])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var size := tex.get_size()
	label.size = Vector2(size.x + 8.0, 12.0)
	label.position = Vector2(-label.size.x * 0.5, -7.0)
	spr.add_child(label)
	_buttons.append({
		"action": def[0], "pos": pos, "radius": radius, "size": size,
		"node": spr, "group": group, "held": false,
	})


# ---------------------------------------------------------------------------
# 화면 상태

## 지금 무엇을 보여줄지: "hidden"(타이틀·리플레이) / "menu"(설정·일시정지·기록) / "play"
func mode() -> String:
	var parent := get_parent()
	if parent != null and parent.has_method("is_replaying") and parent.call("is_replaying"):
		return "hidden"
	var menu := false
	for n: Node in get_tree().get_nodes_in_group(Crosshair.POINTER_GROUP):
		if n.has_method("is_showing") and n.call("is_showing"):
			if n is TitleScreen:
				return "hidden"
			menu = true
	return "menu" if menu else "play"


func _process(_delta: float) -> void:
	var m := mode()
	var play := m == "play"
	var menu := m == "menu"
	if m == "hidden" and not _touches.is_empty():
		_release_all()
	_set_stick_visible(_move_stick, play or menu)
	_set_stick_visible(_aim_stick, play)
	for b: Dictionary in _buttons:
		var show: bool = (b.group == "menu" and menu) or (b.group != "menu" and play)
		var node: Sprite2D = b.node
		node.visible = show
		node.modulate.a = _data.pressed_alpha if b.held else _data.idle_alpha
		# 화면이 바뀌어 숨은 버튼을 누르고 있었다면 뗀다
		if not show and b.held:
			_release_button(b)


func _set_stick_visible(stick: Dictionary, show: bool) -> void:
	var base: Sprite2D = stick.base
	var knob: Sprite2D = stick.knob
	base.visible = show
	knob.visible = show
	var held: bool = stick.value != Vector2.ZERO
	base.modulate.a = _data.pressed_alpha if held else _data.idle_alpha
	knob.modulate.a = base.modulate.a
	knob.position = stick.center + stick.value * _data.stick_radius


# ---------------------------------------------------------------------------
# 터치 입력

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _on_press(t.index, t.position):
				get_viewport().set_input_as_handled()
		else:
			_on_release(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _touches.has(d.index):
			_on_drag(d.index, d.position)
			get_viewport().set_input_as_handled()


## 누른 곳에 있는 것을 잡는다. 잡았으면 true
func _on_press(index: int, pos: Vector2) -> bool:
	var m := mode()
	if m == "hidden":
		return false
	# 버튼이 조이스틱보다 먼저 (조이스틱 잡는 범위가 넓어서)
	for b: Dictionary in _buttons:
		var node: Sprite2D = b.node
		if node.visible and _button_hit(b, pos):
			_touches[index] = b
			_press_button(b)
			return true
	var move_base: Sprite2D = _move_stick.base
	if move_base.visible and pos.distance_to(_move_stick.center) <= _data.stick_grab_radius:
		_touches[index] = "move"
		_on_drag(index, pos)
		return true
	var aim_base: Sprite2D = _aim_stick.base
	if aim_base.visible and pos.distance_to(_aim_stick.center) <= _data.stick_grab_radius:
		_touches[index] = "aim"
		_on_drag(index, pos)
		return true
	return false


func _button_hit(b: Dictionary, pos: Vector2) -> bool:
	var r: float = b.radius
	if r > 0.0:
		return pos.distance_to(b.pos) <= r
	var half: Vector2 = b.size * 0.5
	return absf(pos.x - b.pos.x) <= half.x + 1.0 and absf(pos.y - b.pos.y) <= half.y + 1.0


func _on_drag(index: int, pos: Vector2) -> void:
	var what: Variant = _touches.get(index)
	if what is String:
		var stick := _move_stick if what == "move" else _aim_stick
		var v: Vector2 = (pos - stick.center) / _data.stick_radius
		v = v.limit_length(1.0)
		if v.length() < _data.stick_deadzone:
			v = Vector2.ZERO
		stick.value = v
		if what == "move":
			_set_move(v)
		else:
			_set_aim(v)


func _on_release(index: int) -> void:
	var what: Variant = _touches.get(index)
	_touches.erase(index)
	if what is Dictionary:
		_release_button(what)
	elif what == "move":
		_move_stick.value = Vector2.ZERO
		_set_move(Vector2.ZERO)
	elif what == "aim":
		_aim_stick.value = Vector2.ZERO
		_set_aim(Vector2.ZERO)


func _release_all() -> void:
	for index: int in _touches.keys():
		_on_release(index)


# ---------------------------------------------------------------------------
# 액션으로 바꾸기

func _press_button(b: Dictionary) -> void:
	b.held = true
	_send_action(b.action, true)


func _release_button(b: Dictionary) -> void:
	if not b.held:
		return
	b.held = false
	_send_action(b.action, false)
	for index: int in _touches.keys():
		if _touches[index] == b:
			_touches.erase(index)


## 키를 누르고 뗀 것과 똑같이 이벤트를 흘려보낸다 (메뉴의 _unhandled_input 도 받는다)
func _send_action(action: StringName, pressed: bool, strength: float = 1.0) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = strength if pressed else 0.0
	Input.parse_input_event(ev)


func _set_move(v: Vector2) -> void:
	move_vec = v
	var parts := [maxf(-v.x, 0.0), maxf(v.x, 0.0), maxf(-v.y, 0.0), maxf(v.y, 0.0)]
	for i in MOVE_ACTIONS.size():
		var action := MOVE_ACTIONS[i]
		var strength: float = parts[i]
		if strength > 0.0:
			Input.action_press(action, strength)
		else:
			Input.action_release(action)
		# 메뉴(스킬 고르기·이니셜)용 방향 입력은 끝까지 밀었을 때 한 번만
		var past: bool = strength >= _data.menu_direction_threshold
		if past and not _menu_dirs_sent.get(action, false):
			_menu_dirs_sent[action] = true
			_send_action(action, true, strength)
		elif not past:
			_menu_dirs_sent[action] = false


func _set_aim(v: Vector2) -> void:
	aim_vec = v
	if v != Vector2.ZERO:
		aim_dir = v.normalized()
	var fire := v.length() >= _data.aim_fire_threshold
	if fire != _firing:
		_firing = fire
		_send_action(&"shoot", fire)


## 조준점 (월드 좌표): 플레이어 총구 높이에서 조준 방향으로 aim_distance 만큼
func aim_world() -> Vector2:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Node2D
	if player == null:
		return Vector2.ZERO
	var origin := player.global_position + Vector2(0.0, -DB.gun.muzzle_height)
	return (origin + aim_dir * _data.aim_distance).round()
