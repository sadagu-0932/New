class_name CrystalSwitchData
extends Resource
## 수정 스위치 크기. 실제 값은 res://data/props/crystal_switch.tres

## 몸통(벽 판정) 반지름·아래쪽 오프셋 (px)
@export var body_radius: float = 0.0
@export var body_offset_y: float = 0.0
## 맞는 판정 반지름 (px)
@export var hurtbox_radius: float = 0.0
## 꺼져 있을 때 깜빡여 눈에 띄게 (한 번 밝아졌다 어두워지는 틱 / 밝아지는 정도 0~1, 화면 표시만)
@export var pulse_period_ticks: int = 0
@export var pulse_strength: float = 0.0
