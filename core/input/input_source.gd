class_name InputSource
extends RefCounted
## 입력 공급원 베이스. 실제 장치(LiveInputSource) / 미리 정한 입력(ScriptedInputSource, 테스트·리플레이)


## 이번 틱의 입력을 돌려준다
func next_frame() -> InputFrame:
	return InputFrame.new()
