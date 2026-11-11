extends Node
## 전역 게임 상태 (오토로드 Game): 설정, 틱 카운터, 시드 RNG.
## 게임 로직은 전부 _physics_process(고정 60틱)에서만 돌린다.

var config: GameConfig
var rng: SeededRng = SeededRng.new()
## 현재 런이 시작된 뒤 지난 틱 수
var tick: int = 0
## 출발했는지 (런 시작 후 첫 조작 입력). 출발 전에만 Tab 으로 스킬을 바꿀 수 있다
var clock_running: bool = false
## 출발한 틱. 기록 = clock_end_tick - clock_start_tick
var clock_start_tick: int = 0
## 골렘 1페이즈 격파로 타이머가 멈췄는지, 멈춘 틱
var clock_stopped: bool = false
var clock_end_tick: int = 0


func _ready() -> void:
	config = DB.game_config
	# 다른 노드보다 먼저 틱을 올린다 (값이 작을수록 먼저 실행)
	process_physics_priority = -1001
	if Engine.physics_ticks_per_second != config.tick_rate:
		push_error("틱 설정 불일치: project.godot=%d, data/game_config.tres=%d"
			% [Engine.physics_ticks_per_second, config.tick_rate])
	reset_run()
	Events.boss_defeated.connect(func(_b: Node2D) -> void: stop_clock())


## 런을 처음 상태로 되돌린다 (틱·RNG 초기화). seed_value < 0 이면 설정의 시드
func reset_run(seed_value: int = -1) -> void:
	tick = 0
	clock_running = false
	clock_start_tick = 0
	clock_stopped = false
	clock_end_tick = 0
	rng.reset(config.run_seed if seed_value < 0 else seed_value)


## 출발선을 넘을 때(StartLine) 또는 출발선 없는 맵에서 첫 조작 입력 때(PlayerInput) 부른다
func start_clock() -> void:
	if clock_running:
		return
	clock_running = true
	clock_start_tick = tick
	Events.clock_started.emit()


## 타이머 정지 (골렘 1페이즈 격파)
func stop_clock() -> void:
	if not clock_running or clock_stopped:
		return
	clock_stopped = true
	clock_end_tick = tick


## 지금까지의 기록 (틱)
func elapsed_ticks() -> int:
	if not clock_running:
		return 0
	return (clock_end_tick if clock_stopped else tick) - clock_start_tick


func is_demo_mode() -> bool:
	return config.demo_mode


func is_story_mode() -> bool:
	return config.story_mode


# 주의: 이 스크립트는 DB 가 data 를 preload 하는 도중에 불려 컴파일된다 (dodge.tres → DashDodge → Game).
# 여기서 Story·Inventory·Player 를 참조하면 내보낸 빌드에서 순환 참조로 스크립트 로드가 깨진다.


func _physics_process(_delta: float) -> void:
	tick += 1
