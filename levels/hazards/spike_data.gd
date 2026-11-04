class_name SpikeData
extends Resource
## 가시 함정 수치. 실제 값은 res://data/hazards/spike.tres

## 가시가 올라와 있는 틱 / 내려가 있는 틱
@export var up_ticks: int = 0
@export var down_ticks: int = 0
## 올라오기 전 예고 틱 (내려가 있는 시간에 포함)
@export var warn_ticks: int = 0
@export var damage: int = 0
## 판정 사각형 한 변 (px)
@export var hitbox_size: float = 0.0
## 맵 글자 'x' 함정의 위상 차이 (틱). 'X' 와 엇갈려 올라온다
@export var alt_phase_ticks: int = 0
