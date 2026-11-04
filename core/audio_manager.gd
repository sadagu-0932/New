extends Node
## 효과음 관리 (오토로드 Audio). 슬롯: 사격·근접·패링·완벽 판정·피격·보스.
## 이벤트 버스에 연결해 알아서 울린다. 파일이 없으면 무음 (오류 없음).

const SLOTS := ["shoot", "melee", "parry", "perfect", "hit", "boss"]

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var data := DB.audio
	for slot: String in SLOTS:
		var path: String = data.get(slot)
		if not path.is_empty() and ResourceLoader.exists(path):
			_streams[slot] = load(path)
	for i in maxi(data.voices, 1):
		var p := AudioStreamPlayer.new()
		p.volume_db = data.volume_db
		add_child(p)
		_players.append(p)
	Events.player_shot.connect(func() -> void: play("shoot"))
	Events.melee_started.connect(func() -> void: play("melee"))
	Events.parried.connect(func(perfect: bool) -> void: play("perfect" if perfect else "parry"))
	Events.perfect_dodge.connect(func() -> void: play("perfect"))
	Events.player_hit.connect(func(_h: HitInfo) -> void: play("hit"))
	Events.boss_started.connect(func(_b: Node2D) -> void: play("boss"))
	Events.boss_defeated.connect(func(_b: Node2D) -> void: play("boss"))


## 이 슬롯에 소리 파일이 있는지
func has_sound(slot: String) -> bool:
	return _streams.has(slot)


## 슬롯 재생. 파일이 없으면 아무것도 안 함. 재생했으면 true
func play(slot: String) -> bool:
	var stream: AudioStream = _streams.get(slot)
	if stream == null:
		return false
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.play()
	return true
