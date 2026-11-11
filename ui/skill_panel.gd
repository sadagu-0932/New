class_name SkillPanel
extends CanvasLayer
## 스킬 설정 창 (Tab). 출발 전(런 시작 후 첫 조작 전)에만 열린다. 열려 있는 동안 게임은 멈춘다.
## 조작: A/D·←/→·1~5 선택, 마우스 올리기 선택 / Tab·Enter·마우스 클릭(뗄 때) 확정 / Esc 취소
## Space·좌클릭 누름은 확정에 쓰지 않는다 (닫자마자 회피·사격으로 출발해 버리지 않게).

const CARD_SIZE := Vector2(56, 62)
const CARD_GAP := 4
const CARDS_Y := 30
## 출발 후 Tab 을 눌렀을 때 알림 표시 시간 (초, 화면 표시)
const NOTICE_SECONDS := 2.0

var run: RunController
var is_open: bool = false
var selected: int = 0

var _root: Control
var _cards: Array[ColorRect] = []
var _desc: Label
var _notice: Label
var _notice_left: float = 0.0
var _was_paused: bool = false


func _init(run_controller: RunController) -> void:
	run = run_controller


## 열려 있는지 (Crosshair 가 포인터로 바꿀 때 사용)
func is_showing() -> bool:
	return _root != null and _root.visible


func _ready() -> void:
	layer = 96
	add_to_group(Crosshair.POINTER_GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var title := UiText.make_label("스킬 설정  (출발 전에만 바꿀 수 있다)")
	title.position = Vector2(0, 10)
	title.size = Vector2(320, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)

	var skills := DB.skills
	var total_w := skills.size() * CARD_SIZE.x + (skills.size() - 1) * CARD_GAP
	var x0 := (320.0 - total_w) * 0.5
	var icons := DB.theme.load_sheet("skill_icons")
	for i in skills.size():
		var sd := skills[i]
		var card := ColorRect.new()
		card.position = Vector2(x0 + i * (CARD_SIZE.x + CARD_GAP), CARDS_Y)
		card.size = CARD_SIZE
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_entered.connect(func() -> void: _select(i))
		card.gui_input.connect(func(ev: InputEvent) -> void: _on_card_input(ev, i))
		_root.add_child(card)
		_cards.append(card)
		var icon := TextureRect.new()
		icon.texture = icons.get_frame_texture(sd.icon, 0)
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.size = Vector2(32, 32)
		icon.position = Vector2((CARD_SIZE.x - 32) * 0.5, 6)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		var name_label := UiText.make_label(sd.display_name)
		name_label.position = Vector2(0, 42)
		name_label.size = Vector2(CARD_SIZE.x, 12)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(name_label)
		var key_label := UiText.make_label(str(i + 1))
		key_label.position = Vector2(3, 1)
		key_label.modulate = Color(1, 1, 1, 0.6)
		card.add_child(key_label)
		if sd.recommended:
			var rec := UiText.make_label("추천")
			rec.position = Vector2(CARD_SIZE.x - 22, 1)
			rec.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.35))
			card.add_child(rec)

	_desc = UiText.make_label()
	_desc.position = Vector2(16, CARDS_Y + CARD_SIZE.y + 8)
	_desc.size = Vector2(288, 40)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_desc)

	var help := UiText.make_label(UiText.for_device("A/D·1~5 고르기   Tab·Enter 확정   Esc 취소"))
	help.position = Vector2(0, 162)
	help.size = Vector2(320, 12)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.modulate = Color(1, 1, 1, 0.7)
	_root.add_child(help)
	_root.visible = false

	# 화면 가운데 두 줄 (한 줄이면 화면 폭을 넘어 오른쪽이 잘린다)
	_notice = UiText.make_label(UiText.for_device("출발한 뒤에는 스킬을 바꿀 수 없다\nR 길게 눌러 처음부터"))
	_notice.position = Vector2(0, 70)
	_notice.size = Vector2(320, 26)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice.visible = false
	add_child(_notice)


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		_notice.visible = _notice_left > 0.0


## 지금 스킬 창을 열 수 있는지
func can_open() -> bool:
	return run != null and run.mode == RunController.Mode.LIVE and not run.showing_result \
		and not Game.clock_running and not run.paused


func open() -> bool:
	if is_open or not can_open():
		return false
	is_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	var current := run.setup.skill
	selected = maxi(DB.skills.find(current), 0)
	_refresh()
	_root.visible = true
	return true


## 고른 스킬로 확정하고 닫는다
func confirm() -> void:
	if not is_open:
		return
	run.change_skill(DB.skills[selected])
	_close()


func cancel() -> void:
	_close()


func _close() -> void:
	is_open = false
	_root.visible = false
	get_tree().paused = _was_paused


func _select(i: int) -> void:
	if not is_open:
		return
	var before := selected
	selected = clampi(i, 0, DB.skills.size() - 1)
	if selected != before:
		Audio.play("ui_move")
	_refresh()


func _refresh() -> void:
	for i in _cards.size():
		_cards[i].color = Color(0.85, 0.65, 0.2, 0.95) if i == selected else Color(0.16, 0.14, 0.2, 0.95)
	var sd := DB.skills[selected]
	_desc.text = "%s  [%s]\n%s" % [sd.display_name, sd.tag, sd.description]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if not is_open:
		if event.is_action_pressed(&"skill_menu") and run != null:
			if not open() and Game.clock_running and run.mode == RunController.Mode.LIVE:
				_notice_left = NOTICE_SECONDS
				_notice.visible = true
			get_viewport().set_input_as_handled()
		return
	var handled := true
	if event.is_action_pressed(&"skill_menu") or event.is_action_pressed(&"menu_confirm"):
		confirm()
	elif event.is_action_pressed(&"pause"):
		cancel()
	elif event.is_action_pressed(&"move_left") or event.is_action_pressed(&"ui_left"):
		_select(posmod(selected - 1, DB.skills.size()))
	elif event.is_action_pressed(&"move_right") or event.is_action_pressed(&"ui_right"):
		_select(posmod(selected + 1, DB.skills.size()))
	else:
		handled = false
		for i in DB.skills.size():
			if event.is_action_pressed(StringName("skill_select_%d" % (i + 1))):
				_select(i)
				handled = true
	if handled:
		get_viewport().set_input_as_handled()


func _on_card_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	# 누를 때 고르고, 뗄 때 확정 (누른 채로 닫혀 사격으로 출발하지 않게)
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		_select(i)
		if not mb.pressed:
			confirm()
