class_name BoulderData
extends Resource
## 굴러오는 바위 수치. 실제 값은 res://data/hazards/boulder.tres

## 발사기에서 바위가 나오는 간격 (틱)
@export var interval_ticks: int = 0
## 발사기마다 시작 시점을 칸 x 좌표 × 이 값 만큼 어긋나게 (틱)
@export var phase_per_column: int = 0
@export var speed: float = 0.0
@export var damage: int = 0
@export var radius: float = 0.0
@export var lifetime_ticks: int = 0
