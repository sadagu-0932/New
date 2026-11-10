extends Node
## 입력 샘플러 (오토로드 PlayerInput).
## 매 틱 가장 먼저 입력을 한 번 읽어 current 에 담는다. 게임 로직은 current 만 본다.

var current: InputFrame = InputFrame.new()
var source: InputSource
## 런 동안 쓴 입력 기록 (리플레이)
var recording: Array[InputFrame] = []
var is_recording: bool = false


func _ready() -> void:
	# Game(-1001) 바로 다음, 다른 게임 노드보다 먼저 실행
	process_physics_priority = -1000
	use_live_input()


## 런 시작 때 기록을 새로 시작
func start_recording() -> void:
	recording.clear()
	is_recording = true


func stop_recording() -> void:
	is_recording = false


func use_live_input() -> void:
	source = LiveInputSource.new(get_viewport())


func _physics_process(_delta: float) -> void:
	current = source.next_frame()
	# 어떤 입력 공급원이든 리플레이에 저장되는 정밀도(1/127)로 맞춘다 → 기록·재생이 항상 똑같다
	current.move = (current.move * Replay.MOVE_SCALE).round() / Replay.MOVE_SCALE
	if is_recording:
		recording.append(current.duplicate_frame())
	# 출발선(StartLine)이 있는 맵은 선을 넘을 때 출발. 없으면 첫 조작 입력 때 출발
	if not Game.clock_running and current.has_any_action() \
			and get_tree().get_first_node_in_group(StartLine.GROUP) == null:
		Game.start_clock()
