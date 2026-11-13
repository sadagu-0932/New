class_name BossBar
extends CanvasLayer
## 화면 위쪽 보스 체력바. 보스가 깨어나면 나타나고, 격파·재시작하면 사라진다.
## 그로기 중엔 노랗게 깜빡인다.
## 지연 체력바: 맞으면 빨간 막대는 바로 줄고, 줄어든 만큼은 밝은 막대로 잠깐 남았다가 천천히 따라 줄어든다
## (data/feel.tres 의 boss_bar_trail_delay · boss_bar_trail_speed). 체력이 다시 차면 바로 같이 찬다

const BAR_SIZE := Vector2(160, 4)
const BAR_Y := 16

var _root: Control
var _fill: ColorRect
## 지연 막대 (빨간 막대 뒤의 밝은 막대)
var _trail: ColorRect
## 지연 막대의 길이 비율 (0~1) · 따라 줄기 시작할 때까지 남은 시간 (초)
var _trail_ratio: float = 1.0
var _trail_wait: float = 0.0
var _hp_ratio: float = 1.0
var _name: Label
var _groggy: bool = false
var _flash_time: float = 0.0


func _ready() -> void:
	layer = 82
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_name = UiText.make_label("탄막 골렘")
	_name.position = Vector2(0, 3)
	_name.size = Vector2(320, 12)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_name)
	var back := ColorRect.new()
	back.color = Color(0.06, 0.04, 0.08, 0.9)
	back.position = Vector2((320 - BAR_SIZE.x) * 0.5 - 1, BAR_Y - 1)
	back.size = BAR_SIZE + Vector2(2, 2)
	_root.add_child(back)
	_trail = ColorRect.new()
	_trail.color = Color(0.97, 0.88, 0.75)
	_trail.position = Vector2((320 - BAR_SIZE.x) * 0.5, BAR_Y)
	_trail.size = BAR_SIZE
	_root.add_child(_trail)
	_fill = ColorRect.new()
	_fill.color = Color(0.77, 0.25, 0.29)
	_fill.position = Vector2((320 - BAR_SIZE.x) * 0.5, BAR_Y)
	_fill.size = BAR_SIZE
	_root.add_child(_fill)
	_root.visible = false
	Events.boss_started.connect(func(_b: Node2D) -> void:
		_root.visible = true
		_trail_ratio = _hp_ratio
		_trail_wait = 0.0)
	Events.boss_hp_changed.connect(_on_hp)
	Events.boss_groggy.connect(_on_groggy)
	Events.boss_defeated.connect(func(_b: Node2D) -> void: _hide())
	Events.run_started.connect(_hide)


func _on_groggy() -> void:
	_groggy = true
	_flash_time = 0.0


func _hide() -> void:
	_root.visible = false
	_groggy = false


func is_showing() -> bool:
	return _root.visible


func _on_hp(current: int, maximum: int) -> void:
	var ratio := clampf(float(current) / float(maxi(maximum, 1)), 0.0, 1.0)
	if ratio < _hp_ratio:
		# 맞음: 지연 막대는 잠깐 그 자리에 남는다 (연달아 맞으면 기다리는 시간을 다시 센다)
		_trail_wait = DB.feel.boss_bar_trail_delay
	else:
		# 회복(2페이즈로 다시 참): 지연 막대도 바로 같이
		_trail_ratio = ratio
	_hp_ratio = ratio
	_fill.size.x = roundf(BAR_SIZE.x * ratio)
	_trail.size.x = roundf(BAR_SIZE.x * _trail_ratio)


## 지연 막대 길이 비율 (테스트용)
func trail_ratio() -> float:
	return _trail_ratio


func _process(delta: float) -> void:
	if _trail_ratio > _hp_ratio:
		if _trail_wait > 0.0:
			_trail_wait -= delta
		else:
			_trail_ratio = maxf(_hp_ratio, _trail_ratio - DB.feel.boss_bar_trail_speed * delta)
		_trail.size.x = roundf(BAR_SIZE.x * _trail_ratio)
	if not _groggy:
		_fill.color = Color(0.77, 0.25, 0.29)
		return
	_flash_time += delta
	var any_groggy := false
	for n in get_tree().get_nodes_in_group(Enemy.GROUP):
		if n is Golem and (n as Golem).is_groggy():
			any_groggy = true
	if not any_groggy:
		_groggy = false
		return
	_fill.color = Color(0.97, 0.78, 0.35) if int(_flash_time * 8.0) % 2 == 0 else Color(0.77, 0.25, 0.29)
