class_name Signpost
extends Node2D
## 표지판 (맵 글자 'I'). 가까이 가면 위에 반투명 글상자로 안내를 보여준다. 게임은 멈추지 않는다.
## 글은 구간 데이터(TutorialSectionData.sign_text)에서 TutorialDirector 가 넣는다.
## 주의: 숨은 테크를 쓰지 않는다.

## 글상자 최대 너비 (px, 화면 표시)
const BOX_WIDTH := 120
const BOX_PADDING := 3
## 화면 위쪽 HUD(체력·타이머) 줄과 겹치지 않게 비워 둘 높이 (px)
const HUD_TOP_MARGIN := 16.0

var text: String = ""
## 이 거리 안이면 글상자 표시 (px, TutorialData.sign_radius)
var radius: float = 0.0

var _box: PanelContainer
var _label: Label


func _ready() -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = DB.theme.load_sheet("props")
	sprite.play(&"sign")
	add_child(sprite)
	_box = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.09, 0.72)
	style.border_color = Color(0.77, 0.54, 0.33, 0.9)
	style.set_border_width_all(1)
	style.set_content_margin_all(BOX_PADDING)
	_box.add_theme_stylebox_override(&"panel", style)
	_box.z_index = 50
	_label = UiText.make_label()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = BOX_WIDTH - BOX_PADDING * 2
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_label)
	_box.visible = false
	add_child(_box)


func set_text(value: String) -> void:
	text = value
	if _label:
		_label.text = value


func is_showing() -> bool:
	return _box.visible


func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Node2D
	var show := player != null and not text.is_empty() \
		and player.global_position.distance_to(global_position) <= radius
	if show != _box.visible:
		_label.text = text
		_box.visible = show
		_box.reset_size()
		# 표지판 위 가운데. 위가 화면 위쪽(HUD 줄)에 걸리면 표지판 아래로
		var above := -10.0 - _box.size.y
		if global_position.y + above < HUD_TOP_MARGIN:
			above = 10.0
		_box.position = Vector2(-_box.size.x * 0.5, above)
