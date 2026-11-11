class_name SaveConfig
extends Resource
## 스토리판 저장 규칙. 실제 값은 res://data/save.tres

## 저장 파일 폴더
@export var save_dir: String = "user://saves"
## 자동저장 칸 수 (수동 1칸은 따로 → 합쳐서 저장 칸 수)
@export var auto_slots: int = 0
## 자동저장 검사 주기 (초, 게임이 멈춰 있는 시간은 세지 않는다)
@export var autosave_interval_seconds: float = 0.0
## 마지막 저장 위치에서 이 거리(px) 넘게 움직였으면 "좌표가 변했다"로 본다
@export var min_move_distance: float = 0.0
## 저장 알림 글이 떠 있는 시간 (초)
@export var toast_seconds: float = 0.0
## 저장 종류 → 목록에 보일 이름
@export var kind_names: Dictionary = {}
@export var text_saved_manual: String = ""
@export var text_saved_auto: String = ""
@export var text_cannot_save: String = ""
@export var text_no_saves: String = ""
