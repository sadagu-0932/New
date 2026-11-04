class_name LiveInputSource
extends InputSource
## 키보드·마우스(Input Map)에서 입력을 읽는다.
## 액션 이름으로만 읽으므로 게임패드·키 변경은 Input Map 만 고치면 된다.

const BUTTON_ACTIONS := {
	InputFrame.SHOOT: &"shoot",
	InputFrame.MELEE: &"melee",
	InputFrame.DODGE: &"dodge",
	InputFrame.SKILL: &"skill",
	InputFrame.INTERACT: &"interact",
}
## 아날로그 이동값 양자화 단계 (리플레이 저장 시 값이 정확히 재현되도록)
const MOVE_STEPS := 127.0

var _viewport: Viewport


func _init(viewport: Viewport) -> void:
	_viewport = viewport


func next_frame() -> InputFrame:
	var f := InputFrame.new()
	var move := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	# 127 단계 정수로 맞춘다 → 리플레이로 저장·복원해도 값이 정확히 같다
	f.move = (move * MOVE_STEPS).round() / MOVE_STEPS
	var mouse := _viewport.get_canvas_transform().affine_inverse() * _viewport.get_mouse_position()
	f.aim = mouse.round()
	for button: int in BUTTON_ACTIONS:
		var action: StringName = BUTTON_ACTIONS[button]
		if Input.is_action_pressed(action):
			f.held |= button
		if Input.is_action_just_pressed(action):
			f.pressed |= button
	return f
