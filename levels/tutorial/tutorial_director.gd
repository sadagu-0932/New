class_name TutorialDirector
extends Node
## 튜토리얼 진행 관리 (레벨의 자식).
##  - 구간 입장 판정 (구간 시작 표시 1~7 을 넘으면 입장, 앞으로만) → Events.section_entered (스플릿 지점)
##  - 하단 안내 문구 표시·자동 숨김 (게임을 멈추지 않음). 출발 전엔 스킬 설정(Tab) 안내를 먼저
##    통과 조건(pass_condition)이 있으면 그 아래 줄에 문이 열릴 때까지 계속 보인다 (남은 적 수 포함)
##  - 표지판 글 넣기
##  - 근접 구간 입장 시 탄약 0
##  - 구간 문 열기 (적 전멸 / 수정 스위치)
##  - 구간마다 스토리 트리거 자리 배치 (데모에서는 비활성)

var level: Level
var data: TutorialData
## 지금 들어와 있는 구간 (1~7, 0 = 아직 없음)
var section: int = 0

## 구간 번호 → 시작 x 좌표 (px)
var _start_x: Dictionary = {}
## 구간 번호 → { "enemies": [], "gates": [], "switches": [] }
var _contents: Dictionary = {}
var _opened: Dictionary = {}
var _hint_hide_timer: int = -1
var _hint_signal: Signal
var _hint_callable: Callable
## 지금 보이는 명령 문구 (행동하면 사라진다) — 통과 조건 줄과 합쳐서 보여준다
var _command: String = ""
## 보스를 쓰러뜨린 구간 (통과 조건 줄을 더 보이지 않는다)
var _done: Dictionary = {}


func _init(owner_level: Level, tutorial: TutorialData) -> void:
	level = owner_level
	data = tutorial


func _ready() -> void:
	var keys: Array = level.map.section_cells.keys()
	keys.sort()
	for k: int in keys:
		_start_x[k] = LevelMap.cell_center(level.map.section_cells[k]).x
		_contents[k] = {"enemies": [], "gates": [], "switches": []}
		var trigger := StoryTrigger.new(_section_data(k).story_id if _section_data(k) else "", data.story_trigger_radius)
		trigger.position = LevelMap.cell_center(level.map.section_cells[k])
		add_child(trigger)
	for node in level.props.get_children():
		var k := section_of(node.position.x)
		if k == 0:
			continue
		if node is Enemy:
			_contents[k]["enemies"].append(node)
		elif node is Gate:
			_contents[k]["gates"].append(node)
		elif node is CrystalSwitch:
			_contents[k]["switches"].append(node)
		elif node is Signpost:
			var sign := node as Signpost
			sign.radius = data.sign_radius
			sign.set_text(_section_data(k).sign_text if _section_data(k) else "")
	Events.enemy_died.connect(func(_e: Node2D) -> void: _on_progress())
	Events.switch_activated.connect(func(_s: Node2D) -> void: _on_progress())
	Events.boss_defeated.connect(func(_b: Node2D) -> void:
		_done[section] = true
		_command = "")
	Events.clock_started.connect(_on_clock_started)
	_check_all_gates()
	_enter(1)


func _exit_tree() -> void:
	_disconnect_hint_signal()
	Events.hint_changed.emit("")


## x 좌표(px)가 속한 구간 번호 (구간 1 시작보다 왼쪽이면 1)
func section_of(x: float) -> int:
	var result := 0
	for k: int in _start_x:
		if x >= _start_x[k] - LevelMap.TILE_SIZE * 0.5 and k > result:
			result = k
	return maxi(result, 1) if not _start_x.is_empty() else 0


func _section_data(k: int) -> TutorialSectionData:
	if k >= 1 and k <= data.sections.size():
		return data.sections[k - 1]
	return null


func _physics_process(_delta: float) -> void:
	var player := level.player
	# 순간이동·디버그 이동으로 여러 구간을 한 번에 넘어도 차례대로 모두 입장 처리
	while player and _start_x.has(section + 1) and player.global_position.x >= _start_x[section + 1]:
		_enter(section + 1)
	if _hint_hide_timer >= 0:
		_hint_hide_timer -= 1
		if _hint_hide_timer < 0:
			_command = ""
			_refresh_hint()


func _enter(k: int) -> void:
	section = k
	Events.section_entered.emit(k)
	var sd := _section_data(k)
	if sd == null:
		return
	if sd.drain_ammo and level.player:
		level.player.ammo.set_current(0)
	if k == 1 and not Game.clock_running and not data.pre_start_hint.is_empty():
		# 출발 전: 스킬 설정 안내가 먼저. 출발하면 1구간 문구로 바뀐다
		_disconnect_hint_signal()
		_hint_hide_timer = -1
		_command = ""
		Events.hint_changed.emit(data.pre_start_hint)
		return
	_show_hint(sd)


func _on_clock_started() -> void:
	if section == 1 and _section_data(1):
		_show_hint(_section_data(1))


func _show_hint(sd: TutorialSectionData) -> void:
	_disconnect_hint_signal()
	_hint_hide_timer = -1
	_command = sd.hint
	_refresh_hint()
	if sd.hint.is_empty() or sd.hint_hide_on.is_empty():
		return
	var sig := _signal_for(sd.hint_hide_on)
	if sig.is_null():
		return
	_hint_signal = sig
	var delay := sd.hint_hide_delay_ticks
	_hint_callable = func(_a: Variant = null) -> void:
		if _hint_hide_timer < 0:
			_hint_hide_timer = delay
	sig.connect(_hint_callable)


## 하단 안내 = 명령 문구 + 통과 조건 줄 (지금 구간)
func _refresh_hint() -> void:
	var lines: Array[String] = []
	if not _command.is_empty():
		lines.append(_command)
	var cond := pass_text(section)
	if not cond.is_empty():
		lines.append(cond)
	Events.hint_changed.emit("\n".join(lines))


## 구간 k 의 통과 조건 줄 (문이 열렸으면 pass_done_text, 조건이 없으면 "")
func pass_text(k: int) -> String:
	var sd := _section_data(k)
	if sd == null or sd.pass_condition.is_empty() or _done.get(k, false):
		return ""
	if _opened.get(k, false) and sd.gate_rule != TutorialSectionData.GateRule.NONE:
		return data.pass_done_text
	if sd.pass_condition.contains("%d"):
		return sd.pass_condition % remaining_enemies(k)
	return sd.pass_condition


## 구간 k 에 살아 있는 적 수
func remaining_enemies(k: int) -> int:
	var n := 0
	for e: Variant in _contents.get(k, {}).get("enemies", []):
		if is_instance_valid(e) and not (e as Enemy).dead:
			n += 1
	return n


func _disconnect_hint_signal() -> void:
	if not _hint_signal.is_null() and _hint_signal.is_connected(_hint_callable):
		_hint_signal.disconnect(_hint_callable)
	_hint_signal = Signal()


static func _signal_for(action: String) -> Signal:
	match action:
		"dodge":
			return Events.player_dodged
		"shoot":
			return Events.player_shot
		"melee":
			return Events.melee_hit
		"parry":
			return Events.parried
		"perfect_dodge":
			return Events.perfect_dodge
		"skill":
			return Events.skill_used
		"switch":
			return Events.switch_activated
	return Signal()


## 적이 쓰러지거나 스위치가 켜짐 → 문 확인 + 통과 조건 줄(남은 수) 갱신
func _on_progress() -> void:
	_check_all_gates()
	var sd := _section_data(section)
	if sd != null and not sd.pass_condition.is_empty() and (not _command.is_empty() or not pass_text(section).is_empty()):
		_refresh_hint()


func _check_all_gates() -> void:
	for k: int in _contents:
		if _opened.get(k, false):
			continue
		var sd := _section_data(k)
		var rule := sd.gate_rule if sd else TutorialSectionData.GateRule.NONE
		var c: Dictionary = _contents[k]
		var ok := true
		match rule:
			TutorialSectionData.GateRule.CLEAR:
				for e: Variant in c["enemies"]:
					if is_instance_valid(e) and not (e as Enemy).dead:
						ok = false
			TutorialSectionData.GateRule.SWITCH:
				for s: Variant in c["switches"]:
					if not (s as CrystalSwitch).is_on:
						ok = false
		if ok:
			_opened[k] = true
			for g: Variant in c["gates"]:
				(g as Gate).open()
			if not (c["gates"] as Array).is_empty():
				Events.gate_opened.emit(k)


## 테스트용: 구간 k 의 내용물
func contents(k: int) -> Dictionary:
	return _contents.get(k, {})
