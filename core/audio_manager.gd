extends Node
## 효과음 관리 (오토로드 Audio).
## 이벤트 버스에 연결해 알아서 울린다. 파일이 없는 슬롯은 무음 (오류 없음).
## 소리 파일: tools/sound_gen.py → art/audio/<슬롯>.wav / 크기·음 높이 변화: data/audio.tres
## 소리는 화면 표시와 같은 "연출"이라 게임 로직·리플레이에 영향을 주지 않는다 (음 높이 무작위도 게임 RNG 를 쓰지 않음).

const SLOTS := [
	"shoot", "empty", "melee", "melee_hit", "parry", "perfect_parry", "dodge", "perfect_dodge",
	"hit", "death", "enemy_hit", "enemy_die",
	"skill", "skill_blink", "skill_absorb", "skill_decoy", "skill_shockwave", "skill_mark",
	"gate", "switch", "start", "split", "boss_start", "boss_groggy", "boss_defeat",
	"ui_move", "ui_confirm",
	# 숨은 테크 (글자 안내가 아니라 발견했을 때의 손맛)
	"execute", "reparry", "dash_slash", "combo",
]

var _data: AudioData
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
## 슬롯 → 마지막으로 울린 시각 (밀리초)
var _last_played: Dictionary = {}
var _combo_stage: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_data = DB.audio
	for slot: String in SLOTS:
		var path := "%s/%s.wav" % [_data.sound_dir, slot]
		if ResourceLoader.exists(path):
			_streams[slot] = load(path)
	for i in maxi(_data.voices, 1):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	Settings.volume_changed.connect(func(_v: float) -> void: _apply_volume())
	_apply_volume()
	Events.player_shot.connect(func() -> void: play("shoot"))
	Events.ammo_empty.connect(func() -> void: play("empty"))
	Events.melee_started.connect(func() -> void: play("melee"))
	Events.melee_hit.connect(func(_count: int) -> void: play("melee_hit"))
	Events.parried.connect(func(perfect: bool) -> void: play("perfect_parry" if perfect else "parry"))
	Events.player_dodged.connect(func(_p: Node2D) -> void: play("dodge"))
	Events.perfect_dodge.connect(func() -> void: play("perfect_dodge"))
	Events.player_hit.connect(func(_h: HitInfo) -> void: play("hit"))
	Events.player_died.connect(func() -> void: play("death"))
	Events.enemy_damaged.connect(func(_e: Node2D, _h: HitInfo) -> void: play("enemy_hit"))
	Events.enemy_died.connect(func(_e: Node2D) -> void: play("enemy_die"))
	Events.skill_used.connect(_on_skill_used)
	Events.skill_changed.connect(func(_id: String) -> void: play("ui_confirm"))
	Events.gate_opened.connect(func(_s: int) -> void: play("gate"))
	Events.switch_activated.connect(func(_s: Node2D) -> void: play("switch"))
	Events.clock_started.connect(func() -> void: play("start"))
	Events.section_entered.connect(_on_section_entered)
	Events.boss_started.connect(func(_b: Node2D) -> void: play("boss_start"))
	Events.boss_groggy.connect(func() -> void: play("boss_groggy"))
	Events.boss_defeated.connect(func(_b: Node2D) -> void: play("boss_defeat"))
	Events.executed.connect(func() -> void: play("execute"))
	Events.reparried.connect(func(_chain: int) -> void: play("reparry"))
	Events.dash_slashed.connect(func() -> void: play("dash_slash"))
	Events.combo_changed.connect(_on_combo_changed)


## 스킬마다 다른 소리 (없으면 공통 스킬 소리)
func _on_skill_used(skill_id: String) -> void:
	if not play("skill_" + skill_id):
		play("skill")


## 2구간부터 구간에 들어설 때 (1구간은 시작이라 울리지 않음)
func _on_section_entered(index: int) -> void:
	if index >= 2 and Game.clock_running:
		play("split")


## 콤보 단계가 오를 때만
func _on_combo_changed(stage: int) -> void:
	if stage > _combo_stage:
		play("combo")
	_combo_stage = stage


## 지금 소리 크기 (0~1, 다이얼 값)
func volume() -> float:
	return Settings.volume if Settings.volume >= 0.0 else _data.volume_default


## 소리 크기 바꾸기 (다이얼 한 칸 단위로 맞춘다)
func set_volume(value: float) -> void:
	var step := maxf(_data.volume_step, 0.001)
	Settings.set_volume(snappedf(clampf(value, 0.0, 1.0), step))


## 다이얼 값을 Master 버스에 반영 (0 이면 끈다)
func _apply_volume() -> void:
	var v := volume()
	AudioServer.set_bus_mute(0, v <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))


## 이 슬롯에 소리 파일이 있는지
func has_sound(slot: String) -> bool:
	return _streams.has(slot)


## 슬롯 재생. 파일이 없으면 아무것도 안 함. 재생했으면 true
func play(slot: String) -> bool:
	var stream: AudioStream = _streams.get(slot)
	if stream == null:
		return false
	# 같은 소리가 거의 동시에 여러 번이면 한 번만 (이미 울렸으니 true)
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(slot, -100000)) < _data.min_gap_ms:
		return true
	_last_played[slot] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = _data.volume_db + float(_data.volumes.get(slot, 0.0))
	p.pitch_scale = 1.0 if _data.fixed_pitch.has(slot) else 1.0 + randf_range(-_data.pitch_random, _data.pitch_random)
	p.play()
	return true
