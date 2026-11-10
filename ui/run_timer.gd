class_name RunTimer
extends CanvasLayer
## 화면 오른쪽 위 타이머 (게임 틱 기준, 밀리초까지 크게). data/game_config 의 show_timer_in_game 이 꺼져 있으면 숨긴다.
## 구간에 들어가면 그 아래에 스플릿 + 1위 기록 대비 차이 (빠르면 초록, 느리면 빨강)를 잠깐 띄운다.

## 스플릿 표시 시간 (초, 화면 표시)
const SPLIT_SECONDS := 3.0
const COLOR_AHEAD := Color(0.49, 0.76, 0.35)
const COLOR_BEHIND := Color(0.77, 0.25, 0.29)

var _time: Label
var _split: Label
var _split_left: float = 0.0
## 비교 기준 (1위 기록의 구간 입장 누적 틱)
var _best_splits: Array = []


func _ready() -> void:
	layer = 81
	# 게임 중 타이머를 숨기는 설정이면 통째로 안 보이게 (시간 재기는 Game 이 따로 한다)
	visible = Game.config.show_timer_in_game
	_time = UiText.make_label("0:00.000", UiText.SIZE_LARGE)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time.position = Vector2(220, -2)
	_time.size = Vector2(96, 22)
	add_child(_time)
	_split = UiText.make_label()
	_split.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_split.position = Vector2(176, 20)
	_split.size = Vector2(140, 12)
	_split.visible = false
	add_child(_split)
	Events.split_recorded.connect(_on_split)
	Events.run_started.connect(_on_run_started)
	_on_run_started()


func _on_run_started() -> void:
	_best_splits = Leaderboard.best().get("split_ticks", [])
	_split.visible = false
	_split_left = 0.0


func _on_split(section: int, ticks: int) -> void:
	if section <= 1 or not Game.clock_running:
		return
	var text := "구간%d  %s" % [section, RunResult.format_ticks(ticks)]
	var color := Color.WHITE
	if section - 1 < _best_splits.size():
		var diff := ticks - int(_best_splits[section - 1])
		text += "  " + RunResult.format_diff(diff)
		color = COLOR_AHEAD if diff <= 0 else COLOR_BEHIND
	_split.text = text
	_split.add_theme_color_override(&"font_color", color)
	_split.visible = true
	_split_left = SPLIT_SECONDS


func _process(delta: float) -> void:
	_time.text = RunResult.format_ticks(Game.elapsed_ticks())
	# 멈췄으면(격파) 노랗게
	_time.modulate = Color(1.0, 0.85, 0.35) if Game.clock_stopped else Color.WHITE
	if _split_left > 0.0:
		_split_left -= delta
		_split.visible = _split_left > 0.0


func split_text() -> String:
	return _split.text if _split.visible else ""
