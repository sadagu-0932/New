extends Node
## 전역 게임 상태 (오토로드 Game): 설정, 틱 카운터, 시드 RNG.
## 게임 로직은 전부 _physics_process(고정 60틱)에서만 돌린다.

var config: GameConfig
var rng: SeededRng = SeededRng.new()
## 현재 런이 시작된 뒤 지난 틱 수
var tick: int = 0


func _ready() -> void:
	config = DB.game_config
	# 다른 노드보다 먼저 틱을 올린다 (값이 작을수록 먼저 실행)
	process_physics_priority = -1001
	if Engine.physics_ticks_per_second != config.tick_rate:
		push_error("틱 설정 불일치: project.godot=%d, data/game_config.tres=%d"
			% [Engine.physics_ticks_per_second, config.tick_rate])
	reset_run()


## 런을 처음 상태로 되돌린다 (틱·RNG 초기화)
func reset_run() -> void:
	tick = 0
	rng.reset(config.run_seed)


func is_demo_mode() -> bool:
	return config.demo_mode


func _physics_process(_delta: float) -> void:
	tick += 1
