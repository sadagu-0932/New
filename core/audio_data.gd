class_name AudioData
extends Resource
## 효과음 설정. 실제 값은 res://data/audio.tres
## 소리 파일은 tools/sound_gen.py 가 sound_dir 에 "<슬롯 이름>.wav" 로 만든다.
## 파일이 없는 슬롯은 무음으로 동작한다 (오류 없음).
## TODO(미정): 음악

## 효과음 폴더
@export_dir var sound_dir: String = ""
## 전체 효과음 크기 (dB)
@export var volume_db: float = 0.0
## 슬롯별 크기 조절 (슬롯 이름 → dB, 없으면 0)
@export var volumes: Dictionary = {}
## 동시에 낼 수 있는 소리 수
@export var voices: int = 0
## 재생할 때마다 음 높이를 이만큼 무작위로 바꾼다 (0.05 = ±5%, 같은 소리 반복이 덜 지루하게)
@export var pitch_random: float = 0.0
## 음 높이를 바꾸지 않는 슬롯 (가락이 있는 소리). 슬롯 이름 → true
@export var fixed_pitch: Dictionary = {}
## 소리 다이얼의 기본값 (0~1, 설정을 저장한 적이 없을 때)
@export var volume_default: float = 1.0
## 소리 다이얼 한 칸 (휠·방향키 한 번에 바뀌는 양)
@export var volume_step: float = 0.05
## 같은 소리가 이 시간(밀리초) 안에 또 울리면 건너뛴다 (한꺼번에 겹쳐 시끄러워지지 않게)
@export var min_gap_ms: int = 0
