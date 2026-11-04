class_name GameConfig
extends Resource
## 게임 전역 설정. 실제 값은 res://data/game_config.tres 에서 읽는다.

## 게임 로직 틱 수 (project.godot 의 physics_ticks_per_second 와 같아야 함)
@export var tick_rate: int = 60
## 데모 모드: 스토리 트리거·스킬 교체 지점·보스 2페이즈 전투를 끈다
@export var demo_mode: bool = true
## 런 고정 시드. 랜덤은 전부 이 시드의 RNG 하나로만 뽑는다
@export var run_seed: int = 0
## 시작 맵 (M4에서 튜토리얼 맵으로 교체)
@export_file("*.txt") var start_map_path: String = ""
