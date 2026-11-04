extends Node
## 입력 샘플러 (오토로드 PlayerInput).
## 매 틱 가장 먼저 입력을 한 번 읽어 current 에 담는다. 게임 로직은 current 만 본다.

var current: InputFrame = InputFrame.new()
var source: InputSource


func _ready() -> void:
	# Game(-1001) 바로 다음, 다른 게임 노드보다 먼저 실행
	process_physics_priority = -1000
	use_live_input()


func use_live_input() -> void:
	source = LiveInputSource.new(get_viewport())


func _physics_process(_delta: float) -> void:
	current = source.next_frame()
	if not Game.clock_running and current.has_any_action():
		Game.start_clock()
