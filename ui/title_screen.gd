class_name TitleScreen
extends CanvasLayer
## 타이틀 화면. 아무 키(뗄 때)나 클릭하면 시작. 입력이 없으면 일정 시간 뒤 1위 기록 리플레이 자동 재생 (어트랙트 모드).
## 리플레이 중 아무 키나 누르면 타이틀로 돌아온다 (App 이 처리).

signal start_requested()
signal attract_requested()

var _root: Control
var _press: Label
var _board: Label
var _idle: float = 0.0
var _blink: float = 0.0


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
	var sub := UiText.make_label("튜토리얼 스피드런")
	sub.position = Vector2(0, 50)
	sub.size = Vector2(320, 12)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate.a = 0.7
	_root.add_child(sub)
	_board = UiText.make_label()
	_board.position = Vector2(0, 76)
	_board.size = Vector2(320, 48)
	_board.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_board)
	_press = UiText.make_label("아무 키나 눌러 시작")
	_press.position = Vector2(0, 140)
	_press.size = Vector2(320, 12)
	_press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_press)
	refresh()


## 타이틀을 다시 보여줄 때 (순위 갱신, 대기 시간 초기화)
func refresh() -> void:
	_idle = 0.0
	var lines: Array[String] = ["최고 기록"]
	var entries := Leaderboard.load_entries()
	for i in mini(3, entries.size()):
		var e := entries[i]
		var sd := DB.skill_by_id(String(e.get("skill_id", "")))
		lines.append("%d  %s  %s  %s" % [i + 1, e["initials"], RunResult.format_ticks(int(e["ticks"])), sd.display_name if sd else ""])
	if entries.is_empty():
		lines.append("아직 기록 없음 — 첫 기록의 주인공이 되자")
	_board.text = "\n".join(lines)


func set_visible_screen(value: bool) -> void:
	_root.visible = value
	if value:
		refresh()


func is_showing() -> bool:
	return _root.visible


func _process(delta: float) -> void:
	if not _root.visible:
		return
	_blink += delta
	_press.modulate.a = 1.0 if int(_blink * 2.0) % 2 == 0 else 0.35
	_idle += delta
	if _idle >= DB.game_config.attract_idle_seconds:
		_idle = 0.0
		if Replay.load_best() != null:
			attract_requested.emit()


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventMouseMotion:
		return
	_idle = 0.0
	# 뗄 때 시작 → 시작 키가 곧바로 게임 입력(회피·사격)으로 이어지지 않게
	var released := (event is InputEventKey and not event.is_pressed() and not event.is_echo()) \
		or (event is InputEventMouseButton and not event.is_pressed())
	var ignored := event.is_action(&"toggle_fullscreen") \
		or (event is InputEventKey and AdminPanel.is_admin_combo(event as InputEventKey))
	if released and not ignored:
		get_viewport().set_input_as_handled()
		start_requested.emit()
