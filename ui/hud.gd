class_name Hud
extends CanvasLayer
## 화면 HUD: 왼쪽 위 체력 하트, 왼쪽 아래 탄약 칸. (TODO(M7): 타이머·스플릿)
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
	Events.ammo_changed.connect(_on_ammo_changed)
	Events.player_hp_changed.connect(_on_hp_changed)
	Events.player_spawned.connect(_read_player)
	_read_player(get_tree().get_first_node_in_group(Player.GROUP))


func _read_player(node: Node) -> void:
	var player := node as Player
	if player == null or player.ammo == null:
		return
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


func _draw_hud() -> void:
	for i in _hp_max:
		var heart := _heart_full if i < _hp_current else _heart_empty
		_canvas.draw_texture(heart, MARGIN + Vector2(i * HEART_SPACING, 0))
	var size := _canvas.get_viewport_rect().size
	var y := size.y - MARGIN.y - float(_ammo_full.get_height())
	for i in _ammo_max:
		var tex := _ammo_full if i < _ammo_current else _ammo_empty
		_canvas.draw_texture(tex, Vector2(MARGIN.x + i * PIP_SPACING, y))
