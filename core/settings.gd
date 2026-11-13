extends Node
## 사용자 설정 (오토로드 Settings). user://settings.json 에 저장한다.
## - 키 설정 (PC): 액션마다 키 하나 또는 마우스 버튼 하나
## - 터치 버튼 위치 (모바일): 버튼 이름 → 화면 좌표(320x180 기준)
## 기록·리플레이에는 영향 없음 (리플레이는 액션 단위로 저장된다)

const PATH := "user://settings.json"
## 바꿀 수 있는 액션과 화면에 보일 이름 (이 순서로 키 설정 창에 나온다)
## 스토리판에는 즉시 재시작이 없어 재시작 키는 목록에 없다
const REBINDABLE: Array = [
	[&"move_up", "위로 이동"], [&"move_down", "아래로 이동"], [&"move_left", "왼쪽 이동"], [&"move_right", "오른쪽 이동"],
	[&"shoot", "사격"], [&"melee", "근접·패링"], [&"dodge", "회피"], [&"skill", "스킬1"], [&"skill2", "스킬2"],
	[&"interact", "상호작용"], [&"skill_menu", "인벤토리"], [&"map", "지도"],
]
const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "좌클릭", MOUSE_BUTTON_RIGHT: "우클릭", MOUSE_BUTTON_MIDDLE: "휠클릭",
	MOUSE_BUTTON_XBUTTON1: "마우스4", MOUSE_BUTTON_XBUTTON2: "마우스5",
}

## 소리 크기가 바뀌었을 때 (0~1)
signal volume_changed(value: float)

## 키 설정이나 버튼 위치가 바뀌었을 때 (화면의 키 이름 갱신용)
signal changed()

## 액션 이름 → {"t": "k"|"m", "c": 번호}  (기본값과 다른 것만)
var keys: Dictionary = {}
## 터치 버튼 이름 → [x, y]
var touch_positions: Dictionary = {}
## 소리 크기 0~1 (음수 = 저장한 적 없음 → data/audio.tres 의 volume_default)
var volume: float = -1.0


func _ready() -> void:
	load_settings()
	_apply_keys()
	volume_changed.emit(volume)


## 소리 크기 바꾸기 (0~1, 저장까지)
func set_volume(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(value, volume):
		return
	volume = value
	save_settings()
	volume_changed.emit(volume)


func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		var k: Variant = (parsed as Dictionary).get("keys", {})
		var t: Variant = (parsed as Dictionary).get("touch", {})
		keys = k if k is Dictionary else {}
		touch_positions = t if t is Dictionary else {}
		var v: Variant = (parsed as Dictionary).get("volume", -1.0)
		volume = clampf(float(v), 0.0, 1.0) if (v is float or v is int) and float(v) >= 0.0 else -1.0


func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"keys": keys, "touch": touch_positions, "volume": volume}))


# ---------------------------------------------------------------------------
# 키 설정

func _is_rebindable(action: StringName) -> bool:
	for entry: Array in REBINDABLE:
		if entry[0] == action:
			return true
	return false


func _make_event(d: Dictionary) -> InputEvent:
	if d.get("t", "") == "m":
		var mb := InputEventMouseButton.new()
		mb.button_index = int(d.get("c", 0)) as MouseButton
		return mb
	var key := InputEventKey.new()
	key.physical_keycode = int(d.get("c", 0)) as Key
	return key


func _apply_keys() -> void:
	InputMap.load_from_project_settings()
	for action: String in keys:
		if not _is_rebindable(StringName(action)) or not (keys[action] is Dictionary):
			continue
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, _make_event(keys[action]))


## 액션에 지금 걸린 입력을 {"t","c"} 로
func binding_of(action: StringName) -> Dictionary:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return {"t": "k", "c": int((ev as InputEventKey).physical_keycode)}
		if ev is InputEventMouseButton:
			return {"t": "m", "c": int((ev as InputEventMouseButton).button_index)}
	return {}


## 화면에 보일 키 이름 (Space, Q, 좌클릭 …)
func key_name(action: StringName) -> String:
	var b := binding_of(action)
	if b.is_empty():
		return "-"
	if b.t == "m":
		return MOUSE_NAMES.get(int(b.c), "마우스%d" % int(b.c))
	return OS.get_keycode_string(int(b.c) as Key)


## 이동 키 네 개를 한 덩어리로 (기본 "WASD")
func move_keys_name() -> String:
	var names: Array[String] = []
	var short := true
	for action: StringName in [&"move_up", &"move_left", &"move_down", &"move_right"]:
		var n := key_name(action)
		names.append(n)
		short = short and n.length() == 1
	return "".join(names) if short else "·".join(names)


## 눌린 입력을 키 설정에 쓸 수 있는 꼴로. 못 쓰는 입력이면 빈 Dictionary
func binding_from_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var code := int((event as InputEventKey).physical_keycode)
		# Esc(일시정지)·Enter(확인)는 메뉴용이라 쓸 수 없다
		if code == KEY_ESCAPE or code == KEY_ENTER or code == KEY_KP_ENTER or code == 0:
			return {}
		return {"t": "k", "c": code}
	if event is InputEventMouseButton and event.is_pressed():
		var index := int((event as InputEventMouseButton).button_index)
		if MOUSE_NAMES.has(index):
			return {"t": "m", "c": index}
	return {}


## 액션의 입력을 바꾼다. 다른 액션과 겹쳐도 그대로 둔다 (겹침은 is_conflicting 으로 알려준다)
func rebind(action: StringName, binding: Dictionary) -> void:
	if binding.is_empty() or not _is_rebindable(action):
		return
	keys[String(action)] = binding
	_apply_keys()
	save_settings()
	changed.emit()


## 이 액션의 입력을 다른 액션도 쓰고 있는지
func is_conflicting(action: StringName) -> bool:
	var mine := binding_of(action)
	if mine.is_empty():
		return false
	for entry: Array in REBINDABLE:
		var other: StringName = entry[0]
		if other != action and binding_of(other) == mine:
			return true
	return false


func has_conflicts() -> bool:
	for entry: Array in REBINDABLE:
		if is_conflicting(entry[0]):
			return true
	return false


func reset_keys() -> void:
	keys.clear()
	_apply_keys()
	save_settings()
	changed.emit()


# ---------------------------------------------------------------------------
# 터치 버튼 위치

func touch_position(id: String, fallback: Vector2) -> Vector2:
	var v: Variant = touch_positions.get(id)
	if v is Array and (v as Array).size() == 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback


func set_touch_position(id: String, pos: Vector2) -> void:
	touch_positions[id] = [pos.x, pos.y]


func reset_touch_positions() -> void:
	touch_positions.clear()
	save_settings()
	changed.emit()
