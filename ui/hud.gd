class_name Hud
extends CanvasLayer
## 화면 HUD: 왼쪽 위 체력 하트, 왼쪽 아래 탄약 칸, 오른쪽 아래 스킬(쿨타임). (TODO(M7): 타이머·스플릿)
## 숫자 없이 아이콘만. 숨은 테크 관련 표시는 절대 넣지 않는다.

const MARGIN := Vector2(4, 4)
const PIP_SPACING := 5
const HEART_SPACING := 9

var _ammo_current: int = 0
var _ammo_max: int = 0
var _hp_current: int = 0
var _hp_max: int = 0
var _canvas: Control
var _ammo_full: Texture2D
var _ammo_empty: Texture2D
var _heart_full: Texture2D
var _heart_empty: Texture2D
var _skill_icons: SpriteFrames
var _player: Player
var _q_label: Label


func _ready() -> void:
	layer = 80
	var icons := DB.theme.load_sheet("ui_icons")
	_ammo_full = icons.get_frame_texture(&"ammo_full", 0)
	_ammo_empty = icons.get_frame_texture(&"ammo_empty", 0)
	_heart_full = icons.get_frame_texture(&"heart_full", 0)
	_heart_empty = icons.get_frame_texture(&"heart_empty", 0)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	_skill_icons = DB.theme.load_sheet("skill_icons")
	_q_label = UiText.make_label("Q")
	_q_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_q_label.position = Vector2(320 - MARGIN.x - 16 - 8, 180 - MARGIN.y - 12)
	add_child(_q_label)
	Events.ammo_changed.connect(_on_ammo_changed)
	Events.player_hp_changed.connect(_on_hp_changed)
	Events.player_spawned.connect(_read_player)
	_read_player(get_tree().get_first_node_in_group(Player.GROUP))


func _read_player(node: Node) -> void:
	var player := node as Player
	if player == null or player.ammo == null:
		return
	_player = player
	_on_ammo_changed(player.ammo.current, player.ammo.maximum)
	_on_hp_changed(player.health.current, player.health.maximum)


func _on_ammo_changed(current: int, maximum: int) -> void:
	_ammo_current = current
	_ammo_max = maximum
	_canvas.queue_redraw()


func _on_hp_changed(current: int, maximum: int) -> void:
	_hp_current = current
	_hp_max = maximum
	_canvas.queue_redraw()


func _process(_delta: float) -> void:
	# 스킬 쿨타임은 매 프레임 바뀌므로 다시 그린다
	_canvas.queue_redraw()


func _draw_hud() -> void:
	for i in _hp_max:
		var heart := _heart_full if i < _hp_current else _heart_empty
		_canvas.draw_texture(heart, MARGIN + Vector2(i * HEART_SPACING, 0))
	var size := _canvas.get_viewport_rect().size
	var y := size.y - MARGIN.y - float(_ammo_full.get_height())
	for i in _ammo_max:
		var tex := _ammo_full if i < _ammo_current else _ammo_empty
		_canvas.draw_texture(tex, Vector2(MARGIN.x + i * PIP_SPACING, y))
	_draw_skill(size)


## 오른쪽 아래 스킬 아이콘. 쿨타임 중엔 위에서부터 어둡게 덮는다
func _draw_skill(size: Vector2) -> void:
	_q_label.visible = false
	if not is_instance_valid(_player) or _player.skill == null:
		return
	var skill := _player.skill
	var pos := size - MARGIN - Vector2(16, 16)
	_canvas.draw_texture(_skill_icons.get_frame_texture(skill.data.icon, 0), pos)
	var ratio := skill.ready_ratio()
	if ratio < 1.0:
		var h := roundf(16.0 * (1.0 - ratio))
		_canvas.draw_rect(Rect2(pos, Vector2(16, h)), Color(0, 0, 0, 0.65))
	_q_label.visible = true
	_q_label.position = pos + Vector2(-8, 4)
