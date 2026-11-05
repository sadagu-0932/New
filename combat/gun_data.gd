class_name GunData
extends Resource
## 사격 수치. 실제 값은 res://data/gun.tres

## 탄창 크기
@export var magazine_size: int = 0
## 시작 탄약
@export var start_ammo: int = 0
## 연사 간격 (틱). 누르고 있으면 이 간격으로 계속 쏜다
@export var fire_interval_ticks: int = 0
## 탄이 나가는 높이 (발 중심에서 위로 px, 총을 든 어깨 높이)
@export var muzzle_height: float = 0.0
## 총구 거리 (어깨에서 조준 방향으로 px)
@export var muzzle_offset: float = 0.0
@export var projectile: ProjectileData
