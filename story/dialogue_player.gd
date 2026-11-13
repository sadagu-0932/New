class_name DialoguePlayer
extends CanvasLayer
## 스토리 트리거의 글을 화면 위쪽에 차례로 흘려 보여준다 (연구소 제어 기록 말투).
## 게임을 멈추지 않고 확인 버튼도 없다. 글은 data/story.tres 의 lines (트리거 id → 글 목록).
## 스피드런 데모에서는 트리거가 비활성이라 호출되지 않는다.
## TODO(S6): NPC 대화용 대사창(넘기기 있는 창)은 따로 만든다

## 나타나고 사라지는 속도 (초당 알파, 화면 표시 전용)
const FADE_SPEED := 4.0
## 하단 안내 문구 바로 윗줄 (위쪽은 표지판 글상자·보스 체력 바와 겹친다)
## 안내 문구가 여러 줄이면 그 위로 올라간다 (HintDisplay.top_y)
const TOP := 142
## 안내 문구 윗줄과의 간격 (px)
const GAP := 2

var _label: Label
var _queue: Array[String] = []
var _ticks_left: int = 0
var _target_alpha: float = 0.0


func _ready() -> void:
	layer = 84
	_label = UiText.make_label()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(0, TOP)
	_label.size = Vector2(320, 12)
	_label.add_theme_color_override(&"font_color", Color(0.62, 0.86, 0.9))
	_label.modulate.a = 0.0
	add_child(_label)
	Events.story_triggered.connect(_on_story_triggered)
	Events.run_started.connect(clear)


func _on_story_triggered(story_id: String) -> void:
	for line: String in DB.story.lines.get(story_id, []):
		_queue.append(line)


## 지금 보이는 글 (없으면 "")
func current_text() -> String:
	return _label.text if _ticks_left > 0 else ""


func clear() -> void:
	_queue.clear()
	_ticks_left = 0
	_target_alpha = 0.0


func _physics_process(_delta: float) -> void:
	if _ticks_left > 0:
		_ticks_left -= 1
		if _ticks_left == 0:
			_target_alpha = 0.0
	elif not _queue.is_empty() and _label.modulate.a <= 0.0:
		_label.text = UiText.for_device(_queue.pop_front())
		_ticks_left = DB.story.line_ticks
		_target_alpha = 1.0


func _process(delta: float) -> void:
	_label.position.y = minf(TOP, HintDisplay.top_y - _label.size.y - GAP)
	_label.modulate.a = move_toward(_label.modulate.a, _target_alpha, FADE_SPEED * delta)
