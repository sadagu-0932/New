class_name HintDisplay
extends CanvasLayer
## 화면 하단 안내 문구. 게임을 멈추지 않고, 진행하면 자동으로 사라진다. 확인 버튼 없음.
## 문구 내용은 data/tutorial.tres (숨은 테크는 절대 넣지 않는다).

## 나타나고 사라지는 속도 (초당 알파, 화면 표시 전용)
const FADE_SPEED := 4.0
## 아래 여백 (px)
const BOTTOM_MARGIN := 14
## 양옆 여백 (px). 긴 문구는 이 안에서 줄을 바꾼다 (화면 밖으로 잘리지 않게)
const SIDE_MARGIN := 24
## 최대 줄 수 (위로 늘어난다)
const MAX_LINES := 4

## 지금 보이는 안내 문구의 맨 윗줄 y (px, 화면 기준). 안 보이면 화면 아래. 다른 글(제어 기록)이 겹치지 않게 피할 때 쓴다
static var top_y: float = 180.0

var _label: Label
var _target_alpha: float = 0.0


func _ready() -> void:
	layer = 85
	_label = UiText.make_label()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 아래에 붙여 쓰고, 여러 줄이면 위로 늘어난다
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_left = SIDE_MARGIN
	_label.offset_right = -SIDE_MARGIN
	_label.offset_top = -BOTTOM_MARGIN - (UiText.SIZE_SMALL + 4) * MAX_LINES
	_label.offset_bottom = -BOTTOM_MARGIN
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.modulate.a = 0.0
	add_child(_label)
	Events.hint_changed.connect(_on_hint_changed)


func _on_hint_changed(text: String) -> void:
	if text.is_empty():
		_target_alpha = 0.0
	else:
		_label.text = UiText.for_device(text)
		_target_alpha = 1.0


func current_text() -> String:
	return _label.text if _target_alpha > 0.0 else ""


func _process(delta: float) -> void:
	_label.modulate.a = move_toward(_label.modulate.a, _target_alpha, FADE_SPEED * delta)
	var lines := _label.get_visible_line_count() if _label.modulate.a > 0.0 else 0
	top_y = _label.get_global_rect().end.y - lines * _label.get_line_height()


func _exit_tree() -> void:
	top_y = 180.0
