class_name Hud
extends CanvasLayer
## 화면 HUD. 지금은 탄약 칸만 (TODO(M3): 체력, TODO(M7): 타이머·스플릿)
## 숨은 테크 관련 표시는 절대 넣지 않는다.

const MARGIN := Vector2(4, 4)
const PIP_SPACING := 5

var _ammo_current: int = 0
var _ammo_max: int = 0
var _canvas: Control
var _full: Texture2D
var _empty: Texture2D


func _ready() -> void:
	layer = 80
	var icons := DB.theme.load_sheet("ui_icons")
	_full = icons.get_frame_texture(&"ammo_full", 0)
	_empty = icons.get_frame_texture(&"ammo_empty", 0)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	Events.ammo_changed.connect(_on_ammo_changed)
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player:
		_on_ammo_changed(player.ammo.current, player.ammo.maximum)


func _on_ammo_changed(current: int, maximum: int) -> void:
	_ammo_current = current
	_ammo_max = maximum
	_canvas.queue_redraw()


func _draw_hud() -> void:
	# 왼쪽 아래에 탄약 칸
	var size := _canvas.get_viewport_rect().size
	var y := size.y - MARGIN.y - float(_full.get_height())
	for i in _ammo_max:
		var tex := _full if i < _ammo_current else _empty
		_canvas.draw_texture(tex, Vector2(MARGIN.x + i * PIP_SPACING, y))
