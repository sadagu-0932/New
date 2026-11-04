class_name HintDisplay
extends CanvasLayer
## 화면 하단 안내 문구. 게임을 멈추지 않고, 진행하면 자동으로 사라진다. 확인 버튼 없음.
## 문구 내용은 data/tutorial.tres (숨은 테크는 절대 넣지 않는다).

## 나타나고 사라지는 속도 (초당 알파, 화면 표시 전용)
const FADE_SPEED := 4.0
## 아래 여백 (px)
const BOTTOM_MARGIN := 14

var _label: Label
var _target_alpha: float = 0.0


func _ready() -> void:
	layer = 85
	_label = UiText.make_label()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_top = -BOTTOM_MARGIN - UiText.SIZE_SMALL
	_label.offset_bottom = -BOTTOM_MARGIN
	_label.modulate.a = 0.0
	add_child(_label)
	Events.hint_changed.connect(_on_hint_changed)


func _on_hint_changed(text: String) -> void:
	if text.is_empty():
		_target_alpha = 0.0
	else:
		_label.text = text
		_target_alpha = 1.0


func current_text() -> String:
	return _label.text if _target_alpha > 0.0 else ""


func _process(delta: float) -> void:
	_label.modulate.a = move_toward(_label.modulate.a, _target_alpha, FADE_SPEED * delta)
