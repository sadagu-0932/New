class_name EnemyData
extends Resource
## 적 공통 수치. 실제 값은 res://data/enemies/*.tres
## 종류별 수치는 하위 클래스(ChargerData 등)에 있다.

@export var max_hp: int = 0
## 이동 속도 (px/s)
@export var move_speed: float = 0.0
@export var body_radius: float = 0.0
@export var hurtbox_radius: float = 0.0
## 몸에 닿으면 주는 데미지 (0 = 없음)
@export var contact_damage: int = 0
## 시야 거리 (px). 벽에 가리지 않고 이 거리 안이면 플레이어를 본다
@export var sight_range: float = 0.0
## 목표 지점에 도착했다고 보는 거리 (px)
@export var arrive_distance: float = 0.0
## 맞았을 때 밀려나는 속도 (px/s)·틱
@export var knockback_speed: float = 0.0
@export var knockback_ticks: int = 0
## 테마의 스프라이트시트 이름
@export var sheet: String = ""
