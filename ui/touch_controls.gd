class_name TouchControls
extends CanvasLayer
## 터치 조작: 안드로이드 APK(기능 태그 "touch_controls"), 그리고 웹 버전을 폰·태블릿 브라우저로 열었을 때.
## PC(Windows·리눅스)와 PC 브라우저의 웹 버전에는 나오지 않는다.
##
## - 왼쪽 조이스틱: 이동 (메뉴에서는 방향 선택)
## - 오른쪽 조이스틱: 끌어서 조준, 끝까지 밀면 그 방향으로 사격 (밀고 있으면 연사)
## - 둥근 버튼: 근접(=패링), 회피, 스킬1, 사용, 스킬2(지금은 잠김)
## - 위쪽 작은 버튼: 일시정지, 재시작(누르고 있기), 스킬 설정
## - 메뉴가 열려 있으면: 확인, 뒤로
##
## 버튼 위치 바꾸기: 일시정지 화면의 [배치] → 버튼·스틱을 끌어 옮기고 [완료] (Settings 에 저장, [초기화] 로 기본 배치)
##
## 버튼은 키보드와 똑같은 Input Map 액션을 눌러 준다 → 게임 로직·리플레이는 키보드와 같은 길로 간다.
## 조준만은 마우스 위치 대신 aim_world() 를 LiveInputSource 가 읽는다.

const FEATURE := "touch_controls"
const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
const ACTION_BUTTONS: Array = [[&"melee", "근접"], [&"dodge", "회피"], [&"skill", "스킬1"], [&"interact", "사용"], [&"skill2", "스킬2"]]
const TOP_BUTTONS: Array = [[&"pause", "멈춤"], [&"restart", "재시작"], [&"skill_menu", "설정"]]
const MENU_BUTTONS: Array = [[&"menu_confirm", "확인"], [&"pause", "뒤로"]]
## 일시정지 화면에서만 나오는 버튼 (버튼 위치 바꾸기 열기)
const PAUSE_BUTTON: Array = [&"open_settings", "배치"]
## 배치 모드에서만 나오는 버튼 (액션이 아니라 여기서 바로 처리)
const EDIT_BUTTONS: Array = [[&"edit_done", "완료"], [&"edit_reset", "초기화"]]
## 배치 모드에서 버튼이 화면 밖으로 나가지 않게 두는 여백
const EDIT_MARGIN := 8.0

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
## 버튼 위치 바꾸는 중
var edit_mode: bool = false
var _firing: bool = false
var _edit_help: Label


static func is_enabled() -> bool:
	if force_enabled or OS.has_feature(FEATURE):
		return true
	# 웹 버전을 스마트폰·태블릿 브라우저로 열었을 때 (안드로이드·아이폰)
	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	# 아이패드 사파리는 맥으로 보고하므로, 맥 + 터치 화면이면 아이패드로 본다
	return OS.has_feature("web_macos") and DisplayServer.is_touchscreen_available()


func _ready() -> void:
	instance = self
	_data = DB.touch
	# 모든 화면 위, 커서(110) 아래
	layer = 105
	process_mode = Node.PROCESS_MODE_ALWAYS
	_strip_mouse_buttons()
	_move_stick = _make_stick("stick:move", _data.move_stick_center)
	_aim_stick = _make_stick("stick:aim", _data.aim_stick_center)
	var round_tex := DB.theme.load_texture("touch_button")
	var small_tex := DB.theme.load_texture("touch_button_small")
	for i in ACTION_BUTTONS.size():
		_add_button(ACTION_BUTTONS[i], _data.action_button_positions[i], round_tex, _data.action_button_radius, "action")
	for i in TOP_BUTTONS.size():
		_add_button(TOP_BUTTONS[i], _data.top_button_positions[i], small_tex, 0.0, "top")
	for i in MENU_BUTTONS.size():
		_add_button(MENU_BUTTONS[i], _data.menu_button_positions[i], small_tex, 0.0, "menu")
	_add_button(PAUSE_BUTTON, _data.pause_button_position, small_tex, 0.0, "pause")
	for i in EDIT_BUTTONS.size():
		_add_button(EDIT_BUTTONS[i], _data.edit_button_positions[i], small_tex, 0.0, "edit")
	_edit_help = UiText.make_label("버튼을 끌어서 옮기세요")
	_edit_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit_help.position = Vector2(0, _data.edit_button_positions[0].y - 24.0)
	_edit_help.size = Vector2(320, 12)
	_edit_help.visible = false
	add_child(_edit_help)


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


func _make_stick(id: String, default_center: Vector2) -> Dictionary:
	var center := Settings.touch_position(id, default_center)
	var base := Sprite2D.new()
	base.texture = DB.theme.load_texture("touch_stick_base")
	base.position = center
	add_child(base)
	var knob := Sprite2D.new()
	knob.texture = DB.theme.load_texture("touch_stick_knob")
	knob.position = center
	add_child(knob)
	return {"id": id, "default": default_center, "center": center, "base": base, "knob": knob, "value": Vector2.ZERO}


func _add_button(def: Array, default_pos: Vector2, tex: Texture2D, radius: float, group: String) -> void:
	var id := "%s:%s" % [group, def[0]]
	# 게임 중 쓰는 버튼만 옮길 수 있다 (메뉴용 버튼은 고정)
	var movable := group == "action" or group == "top"
	var pos := Settings.touch_position(id, default_pos) if movable else default_pos
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
		"id": id, "default": default_pos, "movable": movable,
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
	_edit_help.visible = edit_mode
	if edit_mode:
		# 배치 모드: 옮길 수 있는 것 전부 + 완료·초기화만 보여준다
		_set_stick_visible(_move_stick, true)
		_set_stick_visible(_aim_stick, true)
		for b: Dictionary in _buttons:
			var node: Sprite2D = b.node
			node.visible = b.movable or b.group == "edit"
			node.modulate.a = _data.pressed_alpha
		return
	var paused := _pause_showing()
	_set_stick_visible(_move_stick, play or menu)
	_set_stick_visible(_aim_stick, play)
	for b: Dictionary in _buttons:
		var show: bool = play and b.movable
		if b.group == "menu":
			show = menu
		elif b.group == "pause":
			show = menu and paused
		var node: Sprite2D = b.node
		node.visible = show
		node.modulate.a = _data.pressed_alpha if b.held else _data.idle_alpha
		if _is_locked(b):
			node.modulate.a = _data.locked_alpha
		# 화면이 바뀌어 숨은 버튼을 누르고 있었다면 뗀다
		if not show and b.held:
			_release_button(b)


## 일시정지 화면이 떠 있는지 ([배치] 버튼은 거기서만)
func _pause_showing() -> bool:
	for n: Node in get_tree().get_nodes_in_group(Crosshair.POINTER_GROUP):
		if n is PauseOverlay and (n as PauseOverlay).is_showing():
			return true
	return false


# ---------------------------------------------------------------------------
# 버튼 위치 바꾸기 (배치 모드)

func set_edit_mode(value: bool) -> void:
	if edit_mode == value:
		return
	_release_all()
	edit_mode = value
	if not value:
		Settings.save_settings()


## 옮길 수 있는 것 전부 (스틱 2개 + 게임 중 버튼)
func _movables() -> Array[Dictionary]:
	var out: Array[Dictionary] = [_move_stick, _aim_stick]
	for b: Dictionary in _buttons:
		if b.movable:
			out.append(b)
	return out


func _item_pos(item: Dictionary) -> Vector2:
	return item.center if item.has("center") else item.pos


func _move_item(item: Dictionary, pos: Vector2) -> void:
	pos = pos.clamp(Vector2(EDIT_MARGIN, EDIT_MARGIN), Vector2(320.0 - EDIT_MARGIN, 180.0 - EDIT_MARGIN)).round()
	if item.has("center"):
		item.center = pos
		(item.base as Sprite2D).position = pos
		(item.knob as Sprite2D).position = pos
	else:
		item.pos = pos
		(item.node as Sprite2D).position = pos


func _reset_layout() -> void:
	Settings.reset_touch_positions()
	for item: Dictionary in _movables():
		_move_item(item, item.default)


## 배치 모드에서 누른 곳: 완료·초기화 버튼이거나, 끌어 옮길 것을 잡는다
func _edit_press(index: int, pos: Vector2) -> void:
	for b: Dictionary in _buttons:
		if b.group == "edit" and _button_hit(b, pos):
			if b.action == &"edit_done":
				set_edit_mode(false)
			else:
				_reset_layout()
			return
	var best: Dictionary = {}
	var best_dist := 22.0
	for item: Dictionary in _movables():
		var dist := pos.distance_to(_item_pos(item))
		if dist < best_dist:
			best_dist = dist
			best = item
	if not best.is_empty():
		_touches[index] = {"drag": best, "offset": _item_pos(best) - pos}


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
	if edit_mode:
		_edit_press(index, pos)
		return true
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
	if what is Dictionary and (what as Dictionary).has("drag"):
		_move_item(what.drag, pos + what.offset)
	elif what is String:
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
	if what is Dictionary and (what as Dictionary).has("drag"):
		# 끌어 옮긴 자리를 기억 (파일 저장은 [완료] 때)
		Settings.set_touch_position(what.drag.id, _item_pos(what.drag))
	elif what is Dictionary:
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

## 아직 쓸 수 없는 버튼 (스킬2 칸은 game_config.skill2_enabled 가 켜져야 쓴다)
func _is_locked(b: Dictionary) -> bool:
	return b.action == &"skill2" and not Game.config.skill2_enabled


func _press_button(b: Dictionary) -> void:
	if _is_locked(b):
		return
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
	# 끝까지 밀면 사격 (놓거나 덜 밀면 멈춤)
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
