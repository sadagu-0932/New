extends Node
## 진입점·화면 흐름.
## 타이틀 → (아무 키) → 튜토리얼 런 → 기록 화면 → (Enter) 다시 / (Esc·오래 가만히) 타이틀
## 타이틀에서 오래 가만히 있으면 1위 기록 리플레이 자동 재생 (어트랙트 모드) → 아무 키나 누르면 타이틀
## 스킬은 시작 화면 없이 출발 전 Tab 으로 설정하고, 고른 스킬은 다음 판에도 유지된다.

var run: RunController
var title: TitleScreen
var skill_panel: SkillPanel
var result_screen: ResultScreen
var admin: AdminPanel
## 마지막으로 고른 스킬 (다음 판에도 유지)
var skill_id: String = ""

var _replay_layer: CanvasLayer
var _replay_label: Label


func _ready() -> void:
	skill_id = DB.game_config.default_skill_id
	add_child(Hud.new())
	add_child(HintDisplay.new())
	add_child(BossBar.new())
	add_child(DialoguePlayer.new())
	add_child(Crosshair.new())
	add_child(PauseOverlay.new())
	skill_panel = SkillPanel.new(null)
	add_child(skill_panel)
	add_child(RunTimer.new())
	result_screen = ResultScreen.new(null)
	add_child(result_screen)
	_build_replay_overlay()
	title = TitleScreen.new()
	title.start_requested.connect(start_live)
	title.attract_requested.connect(start_attract)
	add_child(title)
	admin = AdminPanel.new()
	add_child(admin)
	if Debug.enabled:
		add_child(DebugOverlay.new())
	Events.replay_finished.connect(go_title)
	Events.return_to_title.connect(go_title)
	Events.skill_changed.connect(func(id: String) -> void: skill_id = id)
	go_title()


func _build_replay_overlay() -> void:
	_replay_layer = CanvasLayer.new()
	_replay_layer.layer = 97
	add_child(_replay_layer)
	_replay_label = UiText.make_label()
	_replay_label.position = Vector2(0, 150)
	_replay_label.size = Vector2(320, 24)
	_replay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_replay_layer.add_child(_replay_label)
	_replay_layer.visible = false


func _new_run(replay: Replay = null) -> void:
	_free_run()
	get_tree().paused = false
	var setup := RunSetup.from_config(DB.game_config)
	setup.skill = DB.skill_by_id(skill_id)
	run = RunController.new(setup, replay)
	add_child(run)
	# 입력 처리 순서: UI(스킬 창·기록 화면)가 런보다 먼저 받도록 맨 앞에 둔다
	move_child(run, 0)
	skill_panel.run = run
	result_screen.run = run


func _free_run() -> void:
	if run != null:
		remove_child(run)
		run.queue_free()
		run = null


## 실제 플레이 시작
func start_live() -> void:
	title.set_visible_screen(false)
	_replay_layer.visible = false
	PlayerInput.use_live_input()
	_new_run()


## 어트랙트 모드: 1위 기록 리플레이 재생
func start_attract() -> void:
	var replay := Replay.load_best()
	if replay == null:
		return
	title.set_visible_screen(false)
	_new_run(replay)
	_replay_label.text = "리플레이 · 1위 %s %s\n아무 키나 누르면 타이틀로" % [replay.initials, RunResult.format_ticks(replay.total_ticks)]
	_replay_layer.visible = true


func go_title() -> void:
	_free_run()
	PlayerInput.stop_recording()
	PlayerInput.use_live_input()
	get_tree().paused = false
	_replay_layer.visible = false
	title.set_visible_screen(true)


func is_replaying() -> bool:
	return run != null and run.mode == RunController.Mode.REPLAY


func _input(event: InputEvent) -> void:
	# 리플레이 중 아무 키·클릭 → 타이틀
	if is_replaying() and event.is_pressed() and not (event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()
		go_title()
