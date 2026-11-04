class_name ResultScreen
extends CanvasLayer
## 기록 화면. 사진 찍어 올리기 좋게 총 기록·스플릿·순위·스킬을 크게 보여준다.
## 순위권(상위 10)이면 이니셜 3글자 입력 → 등록. Enter 로 처음부터 다시.
## 이니셜: 글자 키로 바로 입력, 또는 W/S(↑/↓) 글자 바꾸기 · A/D(←/→) 칸 이동 · Backspace 지우기 · Enter 확정
## 1위가 되면 그 판의 리플레이를 저장 (어트랙트 모드에서 재생). 오래 가만히 있으면 타이틀로.

enum Phase { HIDDEN, INITIALS, DONE }

const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const COLOR_AHEAD := Color(0.49, 0.76, 0.35)
const COLOR_BEHIND := Color(0.77, 0.25, 0.29)
const COLOR_HIGHLIGHT := Color(0.97, 0.78, 0.35)
const INITIALS_LENGTH := 3

var run: RunController
var phase: Phase = Phase.HIDDEN
var result: RunResult
var rank: int = 0
var initials: Array[String] = ["A", "A", "A"]
var cursor: int = 0
## 방금 등록한 항목의 등록 순서 (리더보드에서 강조)
var _new_order: int = -1
## 입력 없이 지난 시간 (초)
var _idle: float = 0.0

var _root: Control
var _total: Label
var _skill: Label
var _skill_icon: TextureRect
var _splits: VBoxContainer
var _board: VBoxContainer
var _prompt: Label


func _init(run_controller: RunController) -> void:
	run = run_controller


func _ready() -> void:
	layer = 98
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.07, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	_total = UiText.make_label("", UiText.SIZE_LARGE)
	_total.position = Vector2(0, 2)
	_total.size = Vector2(320, 22)
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_total)

	_skill_icon = TextureRect.new()
	_skill_icon.position = Vector2(120, 25)
	_skill_icon.size = Vector2(16, 16)
	_root.add_child(_skill_icon)
	_skill = UiText.make_label()
	_skill.position = Vector2(140, 28)
	_root.add_child(_skill)

	_splits = VBoxContainer.new()
	_splits.position = Vector2(6, 46)
	_splits.add_theme_constant_override(&"separation", 1)
	_root.add_child(_splits)
	_board = VBoxContainer.new()
	_board.position = Vector2(166, 46)
	_board.add_theme_constant_override(&"separation", 0)
	_root.add_child(_board)

	_prompt = UiText.make_label()
	_prompt.position = Vector2(0, 164)
	_prompt.size = Vector2(320, 12)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_prompt)
	_root.visible = false
	Events.run_finished.connect(_on_run_finished)


func is_showing() -> bool:
	return phase != Phase.HIDDEN


func _on_run_finished(r: RefCounted) -> void:
	result = r as RunResult
	rank = Leaderboard.rank_for(result.total_ticks) if result.cleared else 0
	initials = ["A", "A", "A"]
	cursor = 0
	_new_order = -1
	_idle = 0.0
	get_tree().paused = true
	_root.visible = true
	_fill_header()
	_fill_splits()
	_fill_board()
	phase = Phase.INITIALS if rank > 0 else Phase.DONE
	_update_prompt()


func _fill_header() -> void:
	_total.text = RunResult.format_ticks(result.total_ticks)
	var sd := DB.skill_by_id(result.skill_id)
	_skill.text = "%s%s" % [sd.display_name if sd else "-", "" if rank == 0 else "   %d위!" % rank]
	_skill_icon.texture = DB.theme.load_sheet("skill_icons").get_frame_texture(sd.icon, 0) if sd else null


func _fill_splits() -> void:
	for c in _splits.get_children():
		c.queue_free()
	var best: Array = Leaderboard.best().get("split_ticks", [])
	var best_total := int(Leaderboard.best().get("ticks", 0))
	var sections := DB.game_config.tutorial.sections if DB.game_config.tutorial else []
	for k in range(1, result.split_ticks.size() + 1):
		var title: String = sections[k - 1].title if k - 1 < sections.size() else "구간%d" % k
		var line := "%d %s  %s" % [k, title, RunResult.format_ticks(result.segment_ticks(k))]
		var label := UiText.make_label(line)
		# 1위 기록 대비: 그 구간을 마친 시점의 누적 차이
		var mine := result.cumulative_at_end(k)
		var theirs := -1
		if k < best.size():
			theirs = int(best[k])
		elif k == best.size() and best_total > 0:
			theirs = best_total
		if theirs >= 0:
			var diff := mine - theirs
			label.text += "  " + RunResult.format_diff(diff)
			label.add_theme_color_override(&"font_color", COLOR_AHEAD if diff <= 0 else COLOR_BEHIND)
		_splits.add_child(label)


func _fill_board() -> void:
	for c in _board.get_children():
		c.queue_free()
	var title := UiText.make_label("순위")
	title.modulate.a = 0.7
	_board.add_child(title)
	var entries := Leaderboard.load_entries()
	for i in entries.size():
		var e := entries[i]
		var sd := DB.skill_by_id(String(e.get("skill_id", "")))
		var label := UiText.make_label("%2d %s %s %s" % [i + 1, String(e.get("initials", "???")),
			RunResult.format_ticks(int(e["ticks"])), sd.display_name if sd else ""])
		if int(e["order"]) == _new_order:
			label.add_theme_color_override(&"font_color", COLOR_HIGHLIGHT)
		_board.add_child(label)
	if entries.is_empty():
		_board.add_child(UiText.make_label("아직 기록 없음"))


func _update_prompt() -> void:
	match phase:
		Phase.INITIALS:
			var shown := ""
			for i in INITIALS_LENGTH:
				shown += ("[%s]" if i == cursor else " %s ") % initials[i]
			_prompt.text = "이니셜 %s   Enter 등록" % shown
		Phase.DONE:
			_prompt.text = ("순위 밖 · " if rank == 0 else "") + "Enter 다시 하기 · Esc 타이틀"


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.HIDDEN or event.is_echo() or not event.is_pressed():
		return
	_idle = 0.0
	get_viewport().set_input_as_handled()
	if phase == Phase.DONE:
		if event.is_action_pressed(&"menu_confirm"):
			close_and_restart()
		elif event.is_action_pressed(&"pause"):
			close_to_title()
		return
	# 이니셜 입력
	if event.is_action_pressed(&"menu_confirm"):
		confirm_initials()
		return
	var key := event as InputEventKey
	if key and key.keycode == KEY_BACKSPACE:
		cursor = maxi(cursor - 1, 0)
	elif key and key.unicode > 0 and LETTERS.contains(char(key.unicode).to_upper()):
		type_letter(char(key.unicode).to_upper())
		return
	elif event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
		_cycle(1)
	elif event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
		_cycle(-1)
	elif event.is_action_pressed(&"move_left") or event.is_action_pressed(&"ui_left"):
		cursor = maxi(cursor - 1, 0)
	elif event.is_action_pressed(&"move_right") or event.is_action_pressed(&"ui_right"):
		cursor = mini(cursor + 1, INITIALS_LENGTH - 1)
	_update_prompt()


func type_letter(letter: String) -> void:
	initials[cursor] = letter
	cursor = mini(cursor + 1, INITIALS_LENGTH - 1)
	_update_prompt()


func _cycle(delta: int) -> void:
	var i := LETTERS.find(initials[cursor])
	initials[cursor] = LETTERS[posmod(i + delta, LETTERS.length())]


func confirm_initials() -> void:
	if phase != Phase.INITIALS:
		return
	var tag := "".join(initials)
	rank = Leaderboard.submit(tag, result)
	if rank == 1 and result.replay:
		result.replay.initials = tag
		result.replay.save(Replay.best_path)
	for e in Leaderboard.load_entries():
		if String(e["initials"]) == tag and int(e["ticks"]) == result.total_ticks:
			_new_order = maxi(_new_order, int(e["order"]))
	phase = Phase.DONE
	_fill_header()
	_fill_board()
	_update_prompt()


func _process(delta: float) -> void:
	if phase == Phase.HIDDEN:
		return
	_idle += delta
	if _idle >= DB.game_config.result_idle_seconds:
		# 부스: 아무도 없으면 이니셜 입력 없이 타이틀로
		close_to_title()


func close_to_title() -> void:
	phase = Phase.HIDDEN
	_root.visible = false
	get_tree().paused = false
	Events.return_to_title.emit()


func close_and_restart() -> void:
	phase = Phase.HIDDEN
	_root.visible = false
	get_tree().paused = false
	run.restart()
