class_name AdminPanel
extends CanvasLayer
## 부스 관리자 메뉴 (Ctrl+Shift+F12). 리더보드 백업·초기화. 게임 안 다른 곳에는 안내하지 않는다.
## B: 백업 (리더보드·1위 리플레이를 날짜 붙은 파일로 복사) / C 두 번: 초기화 / Esc: 닫기

var is_open: bool = false
var _root: Control
var _msg: Label
var _clear_armed: bool = false
var _was_paused: bool = false


static func is_admin_combo(ev: InputEventKey) -> bool:
	return ev.is_action(&"admin_menu")


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.0, 0.0, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var title := UiText.make_label("관리자 메뉴\n\nB  리더보드 백업\nC  리더보드 초기화 (두 번 누르기)\nEsc  닫기")
	title.position = Vector2(20, 20)
	_root.add_child(title)
	_msg = UiText.make_label()
	_msg.position = Vector2(20, 120)
	_msg.size = Vector2(280, 40)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_msg)
	_root.visible = false


func open() -> void:
	is_open = true
	_clear_armed = false
	_msg.text = "리더보드 %d명 저장됨" % Leaderboard.load_entries().size()
	_was_paused = get_tree().paused
	get_tree().paused = true
	_root.visible = true


func close() -> void:
	is_open = false
	_root.visible = false
	get_tree().paused = _was_paused


func backup() -> String:
	var dest := Leaderboard.backup()
	if FileAccess.file_exists(Replay.best_path) and not dest.is_empty():
		DirAccess.copy_absolute(Replay.best_path, dest.get_basename() + "_replay.json")
	_msg.text = ("백업 완료: " + ProjectSettings.globalize_path(dest)) if not dest.is_empty() else "백업할 기록 없음"
	return dest


func press_clear() -> void:
	if not _clear_armed:
		_clear_armed = true
		_msg.text = "정말 초기화하려면 C 를 한 번 더 (먼저 B 로 백업 권장)"
		return
	Leaderboard.clear()
	Replay.delete_best()
	_clear_armed = false
	_msg.text = "리더보드를 초기화했다"


func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	if event.is_action_pressed(&"admin_menu"):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	get_viewport().set_input_as_handled()
	var key := event as InputEventKey
	if key == null:
		return
	match key.physical_keycode:
		KEY_B:
			backup()
		KEY_C:
			press_clear()
		KEY_ESCAPE:
			close()
