class_name Crosshair
extends CanvasLayer
## 마우스 조준점. OS 커서를 숨기고 픽셀 조준점을 그린다 (화면 표시 전용, 로직은 PlayerInput.aim).

var _sprite: Sprite2D


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sprite = Sprite2D.new()
	_sprite.texture = DB.theme.load_texture("crosshair")
	add_child(_sprite)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _process(_delta: float) -> void:
	_sprite.position = get_viewport().get_mouse_position().round()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
