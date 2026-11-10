class_name Crosshair
extends CanvasLayer
## 마우스 커서. OS 커서를 숨기고 픽셀 그림을 그린다 (화면 표시 전용, 로직은 PlayerInput.aim).
## 메뉴 화면(타이틀·스킬 설정·일시정지·기록 화면)이 열려 있으면 화살표 포인터, 아니면 조준점.
## 메뉴 화면은 POINTER_GROUP 그룹에 들어가 is_showing() 을 제공한다.

const POINTER_GROUP := &"pointer_screen"

var _cross: Sprite2D
var _pointer: Sprite2D


func _ready() -> void:
	# 모든 메뉴 화면(최대 99) 위, 관리자 패널(120) 아래
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cross = Sprite2D.new()
	_cross.texture = DB.theme.load_texture("crosshair")
	add_child(_cross)
	_pointer = Sprite2D.new()
	_pointer.texture = DB.theme.load_texture("pointer")
	# 화살표 끝(왼쪽 위)이 마우스 위치
	_pointer.centered = false
	_pointer.visible = false
	add_child(_pointer)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _process(_delta: float) -> void:
	# 터치 조작(안드로이드)에서는 커서를 그리지 않는다
	if TouchControls.instance != null:
		_pointer.visible = false
		_cross.visible = false
		return
	var pos := get_viewport().get_mouse_position().round()
	var menu := is_menu_open()
	_pointer.visible = menu
	_cross.visible = not menu
	_pointer.position = pos
	_cross.position = pos


## 포인터를 써야 하는 메뉴 화면이 하나라도 열려 있는지
func is_menu_open() -> bool:
	for n: Node in get_tree().get_nodes_in_group(POINTER_GROUP):
		if n.has_method("is_showing") and n.call("is_showing"):
			return true
	return false


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
