class_name ScriptedInputSource
extends InputSource
## 미리 정한 입력을 틱마다 하나씩 내보낸다 (자동 테스트, 나중에 리플레이 재생에도 사용).
## 큐가 비면 빈 입력을 낸다.

var _queue: Array[InputFrame] = []


## 같은 입력을 ticks 번 넣는다. press_buttons 는 첫 틱에만 '새로 누름'으로 들어간다.
func push(move: Vector2, ticks: int, hold_buttons: int = 0, press_buttons: int = 0, aim: Vector2 = Vector2.ZERO) -> void:
	for i in ticks:
		var f := InputFrame.new()
		f.move = move
		f.aim = aim
		f.held = hold_buttons | press_buttons
		f.pressed = press_buttons if i == 0 else 0
		_queue.append(f)


func push_frame(frame: InputFrame) -> void:
	_queue.append(frame)


func remaining() -> int:
	return _queue.size()


func next_frame() -> InputFrame:
	if _queue.is_empty():
		return InputFrame.new()
	return _queue.pop_front()
