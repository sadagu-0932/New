class_name InputFrame
extends RefCounted
## 한 틱 동안의 게임 입력.
## 게임 로직은 Input 을 직접 읽지 않고 PlayerInput.current(이 객체)만 본다.
## → 틱별로 저장하면 그대로 리플레이·고스트가 된다 (M9).

## 버튼 비트
const SHOOT := 1 << 0
const MELEE := 1 << 1
const DODGE := 1 << 2
const SKILL := 1 << 3
const INTERACT := 1 << 4
## 스킬2 (F). 스토리판에서 칸이 열린 뒤에만 쓴다
const SKILL2 := 1 << 5

## 이동 입력 (길이 1 이하)
var move: Vector2 = Vector2.ZERO
## 조준 지점 (월드 좌표, 정수 픽셀)
var aim: Vector2 = Vector2.ZERO
## 누르고 있는 버튼
var held: int = 0
## 이번 틱에 새로 누른 버튼
var pressed: int = 0


func is_held(button: int) -> bool:
	return (held & button) != 0


func is_pressed(button: int) -> bool:
	return (pressed & button) != 0


## 아무 조작이라도 있었는지 (타이머 시작 판정용)
func has_any_action() -> bool:
	return move != Vector2.ZERO or held != 0 or pressed != 0


func duplicate_frame() -> InputFrame:
	var f := InputFrame.new()
	f.move = move
	f.aim = aim
	f.held = held
	f.pressed = pressed
	return f
