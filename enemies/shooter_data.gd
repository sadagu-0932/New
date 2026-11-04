class_name ShooterData
extends EnemyData
## 원거리형 수치. 실제 값은 res://data/enemies/shooter*.tres

@export var projectile: ProjectileData
## 발사 간격 (틱)
@export var fire_interval_ticks: int = 0
## 처음 플레이어를 보고 첫 발까지 틱
@export var first_shot_delay_ticks: int = 0
## 발사 전 예고 모션 틱 (화면 표시)
@export var telegraph_ticks: int = 0
## 이 거리 범위를 유지하려고 움직인다 (px)
@export var keep_min: float = 0.0
@export var keep_max: float = 0.0
## 탄이 나오는 거리 (px)
@export var muzzle_offset: float = 0.0
