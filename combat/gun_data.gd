class_name GunData
extends Resource
## 사격 수치. 실제 값은 res://data/gun.tres

## 탄창 크기
@export var magazine_size: int = 0
## 시작 탄약
@export var start_ammo: int = 0
## 연사 간격 (틱). 누르고 있으면 이 간격으로 계속 쏜다
@export var fire_interval_ticks: int = 0
## 총구 거리 (플레이어 중심에서 px)
@export var muzzle_offset: float = 0.0
@export var projectile: ProjectileData
