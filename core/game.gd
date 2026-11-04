extends Node
## 전역 게임 상태 (오토로드 Game): 설정, 틱 카운터, 시드 RNG.
## 게임 로직은 전부 _physics_process(고정 60틱)에서만 돌린다.

var config: GameConfig
var rng: SeededRng = SeededRng.new()
## 현재 런이 시작된 뒤 지난 틱 수
var tick: int = 0
## 출발했는지 (런 시작 후 첫 조작 입력). 출발 전에만 Tab 으로 스킬을 바꿀 수 있다
var clock_running: bool = false
## 출발한 틱 (TODO(M7): 기록 = 정지 틱 - 이 값)
var clock_start_tick: int = 0


func _ready() -> void:
	config = DB.game_config
	# 다른 노드보다 먼저 틱을 올린다 (값이 작을수록 먼저 실행)
	process_physics_priority = -1001
	if Engine.physics_ticks_per_second != config.tick_rate:
		push_error("틱 설정 불일치: project.godot=%d, data/game_config.tres=%d"
			% [Engine.physics_ticks_per_second, config.tick_rate])
	reset_run()


## 런을 처음 상태로 되돌린다 (틱·RNG 초기화). seed_value < 0 이면 설정의 시드
func reset_run(seed_value: int = -1) -> void:
	tick = 0
	clock_running = false
	clock_start_tick = 0
	rng.reset(config.run_seed if seed_value < 0 else seed_value)


## 첫 조작 입력 때 PlayerInput 이 부른다
func start_clock() -> void:
	if clock_running:
		return
	clock_running = true
	clock_start_tick = tick
	Events.clock_started.emit()


func is_demo_mode() -> bool:
	return config.demo_mode


func _physics_process(_delta: float) -> void:
	tick += 1
