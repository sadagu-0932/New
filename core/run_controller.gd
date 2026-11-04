class_name RunController
extends Node
## 한 판(런) 관리: 레벨 생성, 재시작(R 홀드·사망), 일시정지(Esc).
## 재시작·일시정지는 메타 조작이라 InputFrame(리플레이 입력)에 넣지 않고 Input 에서 직접 읽는다.

var setup: RunSetup
var level: Level
var paused: bool = false

var _restart_hold: int = 0
## R 을 뗐다가 다시 눌러야 다음 재시작 (계속 누르고 있어도 연속 재시작 안 됨)
var _restart_armed: bool = true
## 사망 후 재시작까지 남은 틱 (-1 = 대기 아님)
var _death_timer: int = -1
## 구간별 입장 누적 틱 (인덱스 = 구간-1)
var _splits: Array[int] = []
## 기록 화면을 보여주는 중 (재시작 입력 무시)
var showing_result: bool = false


func _init(run_setup: RunSetup) -> void:
	setup = run_setup


func _ready() -> void:
	# 일시정지 중에도 재시작·해제 입력을 받는다
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.player_died.connect(_on_player_died)
	Events.demo_finished.connect(_on_demo_finished)
	Events.section_entered.connect(_on_section_entered)
	start_run()


## 런을 처음부터 시작 (재시작 포함)
func start_run() -> void:
	if level != null:
		# 같은 틱에 옛 레벨이 그룹 검색에 걸리지 않도록 즉시 트리에서 뺀다
		remove_child(level)
		level.queue_free()
	_set_paused(false)
	_death_timer = -1
	_splits.clear()
	showing_result = false
	Game.reset_run(setup.seed_value)
	level = Level.new()
	level.map_path = setup.map_path
	level.tutorial = setup.tutorial
	level.skill = setup.skill
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	Events.run_started.emit()


func restart() -> void:
	start_run()


## 출발 전에만 스킬을 바꾼다. 바뀌었으면 true
func change_skill(data: SkillData) -> bool:
	if Game.clock_running or data == null:
		return false
	setup.skill = data
	if level and level.player:
		level.player.set_skill(data)
	Events.skill_changed.emit(data.id)
	return true


func _physics_process(_delta: float) -> void:
	if showing_result:
		return
	if Input.is_action_pressed(&"restart"):
		if _restart_armed:
			_restart_hold += 1
			if _restart_hold >= Game.config.restart_hold_ticks:
				_restart_hold = 0
				_restart_armed = false
				restart()
				return
	else:
		_restart_hold = 0
		_restart_armed = true
	if _death_timer >= 0 and not paused:
		_death_timer -= 1
		if _death_timer < 0:
			restart()


## R 홀드 진행도 0~1 (TODO(M7): 화면에 작은 게이지로 표시)
func restart_progress() -> float:
	return float(_restart_hold) / float(maxi(Game.config.restart_hold_ticks, 1))


## 구간 입장 = 스플릿 (출발 전 1구간은 0)
func _on_section_entered(index: int) -> void:
	while _splits.size() < index:
		_splits.append(Game.elapsed_ticks())
	Events.split_recorded.emit(index, _splits[index - 1])


## 이번 판의 결과
func make_result() -> RunResult:
	var r := RunResult.new()
	r.total_ticks = Game.elapsed_ticks()
	r.split_ticks = _splits.duplicate()
	r.skill_id = setup.skill.id if setup.skill else ""
	r.cleared = Game.clock_stopped
	r.seed_value = setup.seed_value
	return r


## 데모 끝 (골렘 컷씬 종료) → 기록 화면 (ResultScreen 이 받아서 끝나면 restart 를 부른다)
func _on_demo_finished() -> void:
	showing_result = true
	Events.run_finished.emit(make_result())


func _on_player_died() -> void:
	_death_timer = Game.config.death_restart_delay_ticks


func _unhandled_input(event: InputEvent) -> void:
	if showing_result:
		return
	if event.is_action_pressed(&"pause"):
		_set_paused(not paused)
		get_viewport().set_input_as_handled()


func _set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	get_tree().paused = value
	Events.pause_changed.emit(value)
