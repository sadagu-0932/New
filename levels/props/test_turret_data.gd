class_name TestTurretData
extends Resource
## 탄 발사대 수치 (패링 연습용, 테스트 방·튜토리얼 4구간). 실제 값은 res://data/props/test_turret.tres

## 발사 간격 (틱)
@export var fire_interval_ticks: int = 0
## 플레이어가 이 거리(px) 안에 있을 때만 쏜다
@export var fire_range: float = 0.0
## 몸통(벽 판정) 한 변 길이, 탄이 나오는 거리 (px)
@export var body_size: float = 0.0
@export var muzzle_offset: float = 0.0
@export var projectile: ProjectileData
