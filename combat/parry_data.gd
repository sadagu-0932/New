class_name ParryData
extends Resource
## 패링·완벽 패링 수치. 실제 값은 res://data/parry.tres

## 패링 성공 시 회복하는 탄약
@export var ammo_on_parry: int = 0
## 반사탄 속도 배율 (원래 탄 속도 기준)
@export var reflect_speed_mult: float = 1.0
@export var reflect_damage: int = 0
@export var reflect_lifetime_ticks: int = 0
## 완벽 패링 판정창: 근접 시작 후 이 틱 수 안에 탄이 닿으면 완벽
@export var perfect_window_ticks: int = 0
## 완벽 패링 반사탄 강화
@export var perfect_damage_mult: float = 1.0
@export var perfect_radius_mult: float = 1.0
@export var perfect_pierce: bool = false
