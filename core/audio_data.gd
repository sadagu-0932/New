class_name AudioData
extends Resource
## 효과음 슬롯. 실제 값은 res://data/audio.tres
## 파일 경로가 비었거나 파일이 없으면 그 소리는 무음으로 동작한다 (데모 필수 아님).
## TODO(미정): 사운드·음악 — art/audio/ 에 파일을 넣고 경로만 채우면 된다

@export_file("*.wav", "*.ogg", "*.mp3") var shoot: String = ""
@export_file("*.wav", "*.ogg", "*.mp3") var melee: String = ""
@export_file("*.wav", "*.ogg", "*.mp3") var parry: String = ""
@export_file("*.wav", "*.ogg", "*.mp3") var perfect: String = ""
@export_file("*.wav", "*.ogg", "*.mp3") var hit: String = ""
@export_file("*.wav", "*.ogg", "*.mp3") var boss: String = ""
## 전체 효과음 크기 (dB)
@export var volume_db: float = 0.0
## 동시에 낼 수 있는 소리 수
@export var voices: int = 0
