class_name DialogueBox
extends CanvasLayer
## 간단한 대사창 (NPC 대화). 화면 아래에 말하는 이 + 대사 한 줄씩, 상호작용 키·Enter·클릭으로 넘긴다.
## 대화하는 동안 주인공은 움직이지 않는다 (게임 자체는 멈추지 않음).
## 열기: Events.dialogue_requested(말하는 이, 대사 목록)

## 열린 직후 이 시간(초) 동안은 넘기기 입력을 무시한다 (말을 건 키 입력이 곧바로 넘기지 않게)
const OPEN_GUARD_SECONDS := 0.15

var is_open: bool = false
var lines: Array = []
var index: int = 0

var _root: Control
var _speaker: Label
var _text: Label
var _next: Label
var _guard: float = 0.0
var _blink: float = 0.0


func _ready() -> void:
	layer = 88
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var box := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.09, 0.9)
	style.border_color = Color(0.77, 0.54, 0.33, 0.9)
	style.set_border_width_all(1)
	box.add_theme_stylebox_override(&"panel", style)
	box.position = Vector2(20, 122)
	box.size = Vector2(280, 52)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	_speaker = UiText.make_label()
	_speaker.position = Vector2(28, 126)
	_speaker.size = Vector2(264, 12)
	_speaker.add_theme_color_override(&"font_color", Color(0.97, 0.78, 0.35))
	_root.add_child(_speaker)
	_text = UiText.make_label()
	_text.position = Vector2(28, 140)
	_text.size = Vector2(264, 30)
	_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_root.add_child(_text)
	_next = UiText.make_label("▼")
	_next.position = Vector2(284, 160)
	_next.size = Vector2(12, 12)
	_root.add_child(_next)
	_root.visible = false
	Events.dialogue_requested.connect(open)
	Events.run_started.connect(_force_close)


func _player() -> Player:
	return get_tree().get_first_node_in_group(Player.GROUP) as Player


func open(speaker: String, dialogue_lines: Array) -> void:
	if is_open or dialogue_lines.is_empty():
		return
	is_open = true
	lines = dialogue_lines
	index = 0
	_guard = OPEN_GUARD_SECONDS
	_speaker.text = speaker
	_text.text = String(lines[0])
	_root.visible = true
	var p := _player()
	if p != null:
		p.set_cutscene_lock(true)


## 다음 줄로. 마지막 줄이면 닫는다
func advance() -> void:
	if not is_open:
		return
	index += 1
	if index >= lines.size():
		close()
		return
	_text.text = String(lines[index])
	Audio.play("ui_move")


func close() -> void:
	if not is_open:
		return
	_force_close()
	var p := _player()
	if p != null:
		p.set_cutscene_lock(false)
	Events.dialogue_finished.emit()


func _force_close() -> void:
	is_open = false
	_root.visible = false


func _process(delta: float) -> void:
	if not is_open:
		return
	_guard = maxf(_guard - delta, 0.0)
	_blink += delta
	_next.modulate.a = 1.0 if int(_blink * 3.0) % 2 == 0 else 0.3


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or event.is_echo() or get_tree().paused:
		return
	var mb := event as InputEventMouseButton
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"menu_confirm") \
			or event.is_action_pressed(&"dodge") or (mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		if _guard <= 0.0:
			advance()
		get_viewport().set_input_as_handled()
