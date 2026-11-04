class_name GameConfig
extends Resource
## 게임 전역 설정. 실제 값은 res://data/game_config.tres 에서 읽는다.

## 게임 로직 틱 수 (project.godot 의 physics_ticks_per_second 와 같아야 함)
@export var tick_rate: int = 60
## 데모 모드: 스토리 트리거·스킬 교체 지점·보스 2페이즈 전투를 끈다
@export var demo_mode: bool = true
## 런 고정 시드. 랜덤은 전부 이 시드의 RNG 하나로만 뽑는다
@export var run_seed: int = 0
## 튜토리얼 (use_tutorial 이 켜져 있으면 이걸로 시작)
@export var tutorial: TutorialData
@export var use_tutorial: bool = true
## 테스트 방 맵 (use_tutorial 이 꺼져 있을 때)
@export_file("*.txt") var start_map_path: String = ""
## 처음 장착하는 스킬 id (출발 전 Tab 으로 변경)
@export var default_skill_id: String = ""
## 리더보드 인원
@export var leaderboard_size: int = 0
## 타이틀에서 이 시간(초) 동안 입력이 없으면 1위 기록 리플레이 자동 재생
@export var attract_idle_seconds: float = 0.0
## 기록 화면에서 이 시간(초) 동안 입력이 없으면 타이틀로
@export var result_idle_seconds: float = 0.0
## 즉시 재시작: R 을 이 틱 수만큼 누르고 있어야 함 (실수 방지)
@export var restart_hold_ticks: int = 0
## 사망 후 자동 재시작까지 틱 (사망 모션을 잠깐 보여줌)
@export var death_restart_delay_ticks: int = 0
