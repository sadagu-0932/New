class_name RunController
extends Node
## 한 판(런) 관리: 레벨 생성, 재시작(R 홀드·사망), 일시정지(Esc).
## 재시작·일시정지는 메타 조작이라 InputFrame(리플레이 입력)에 넣지 않고 Input 에서 직접 읽는다.

enum Mode { LIVE, REPLAY }

var setup: RunSetup
var level: Level
var paused: bool = false
var mode: Mode = Mode.LIVE
## 리플레이 모드에서 재생할 기록
var replay: Replay
var _replay_done: bool = false

var _restart_hold: int = 0
## R 을 뗐다가 다시 눌러야 다음 재시작 (계속 누르고 있어도 연속 재시작 안 됨)
var _restart_armed: bool = true
## 사망 후 재시작까지 남은 틱 (-1 = 대기 아님)
var _death_timer: int = -1
## 구간별 입장 누적 틱 (인덱스 = 구간-1)
var _splits: Array[int] = []
## 기록 화면을 보여주는 중 (재시작 입력 무시)
var showing_result: bool = false
## 스토리판: 불러온 저장의 플레이어 상태 (위치·체력·탄약). 다음 start_run 에서 한 번 적용하고 비운다
var pending_state: Dictionary = {}
## 불러온 체력·탄약을 적용하기까지 남은 틱 (구간 입장 처리가 끝난 뒤에 덮어쓴다)
var _restore_ticks: int = 0
var _restore_state: Dictionary = {}


func _init(run_setup: RunSetup, replay_data: Replay = null) -> void:
	setup = run_setup
	if replay_data:
		mode = Mode.REPLAY
		replay = replay_data
		setup.seed_value = replay_data.seed_value
		var sd := DB.skill_by_id(replay_data.skill_id)
		if sd:
			setup.skill = sd


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
	if mode == Mode.REPLAY:
		PlayerInput.source = replay.make_source()
		PlayerInput.stop_recording()
	elif Game.is_story_mode():
		# 스토리판은 리플레이를 쓰지 않는다 (오래 플레이해도 입력 기록이 쌓이지 않게)
		PlayerInput.stop_recording()
	else:
		PlayerInput.start_recording()
	level = Level.new()
	level.map_path = setup.map_path
	level.tutorial = setup.tutorial
	level.area = setup.area
	level.skill = setup.skill
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	if not pending_state.is_empty() and level.player != null:
		var pos: Array = pending_state.get("pos", [])
		if pos.size() == 2:
			level.player.teleport(Vector2(float(pos[0]), float(pos[1])))
		elif pending_state.has("spawn"):
			# 지역 출입구로 들어옴: 맵의 숫자 칸(없으면 P)에서 시작
			var index := int(pending_state["spawn"])
			if index > 0 and level.map.section_cells.has(index):
				level.player.teleport(LevelMap.cell_center(level.map.section_cells[index]))
		_restore_state = pending_state
		_restore_ticks = 2
		pending_state = {}
	Events.run_started.emit()


func restart() -> void:
	start_run()


## 스킬을 바꿀 수 있는지: 스피드런판은 출발 전에만, 스토리판은 전투 중만 아니면 언제나
func can_change_skill() -> bool:
	if mode == Mode.REPLAY:
		return false
	if Game.is_story_mode():
		return not CombatState.in_combat(get_tree())
	return not Game.clock_running


## 스킬을 바꾼다. 바뀌었으면 true
func change_skill(data: SkillData) -> bool:
	if data == null or not can_change_skill():
		return false
	setup.skill = data
	if level and level.player:
		level.player.set_skill(data)
	Events.skill_changed.emit(data.id)
	return true


## 불러온 체력·탄약 적용
func _apply_restore() -> void:
	var p := level.player if level != null else null
	if p == null:
		return
	if _restore_state.has("hp"):
		p.health.current = clampi(int(_restore_state["hp"]), 1, p.health.maximum)
		Events.player_hp_changed.emit(p.health.current, p.health.maximum)
	if _restore_state.has("ammo"):
		p.ammo.set_current(int(_restore_state["ammo"]))
	_restore_state = {}


func _physics_process(_delta: float) -> void:
	if _restore_ticks > 0 and not paused:
		_restore_ticks -= 1
		if _restore_ticks == 0:
			_apply_restore()
	if showing_result:
		return
	if mode == Mode.REPLAY:
		# 입력을 다 썼는데 격파 전이면 (기록이 잘렸을 때) 재생 종료
		var src := PlayerInput.source as ScriptedInputSource
		if src and src.remaining() == 0 and not Game.clock_stopped and not _replay_done:
			_replay_done = true
			Events.replay_finished.emit()
		return
	# 즉시 재시작(R 홀드)은 스피드런판에만 있다
	if Input.is_action_pressed(&"restart") and not Game.is_story_mode():
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
			if Game.is_story_mode():
				# 스토리판: 처음부터가 아니라 마지막 저장 지점에서 부활 (StoryMain 이 처리)
				Events.story_respawn_requested.emit()
			else:
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


## 이번 판의 리플레이 (실시간 판만)
func make_replay() -> Replay:
	var rp := Replay.new()
	rp.seed_value = setup.seed_value
	rp.skill_id = setup.skill.id if setup.skill else ""
	rp.frames = PlayerInput.recording.duplicate()
	rp.total_ticks = Game.elapsed_ticks()
	return rp


## 데모 끝 (골렘 컷씬 종료) → 기록 화면 (ResultScreen 이 받아서 끝나면 restart 를 부른다)
func _on_demo_finished() -> void:
	showing_result = true
	if mode == Mode.REPLAY:
		Events.replay_finished.emit()
		return
	PlayerInput.stop_recording()
	var result := make_result()
	result.replay = make_replay()
	Events.run_finished.emit(result)


func _on_player_died() -> void:
	if mode == Mode.REPLAY:
		Events.replay_finished.emit()
		return
	_death_timer = Game.config.death_restart_delay_ticks


func _unhandled_input(event: InputEvent) -> void:
	if showing_result or mode == Mode.REPLAY:
		return
	if event.is_action_pressed(&"pause"):
		_set_paused(not paused)
		get_viewport().set_input_as_handled()


func set_paused(value: bool) -> void:
	_set_paused(value)


func _set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	get_tree().paused = value
	Events.pause_changed.emit(value)
