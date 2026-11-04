class_name TestTurretData
extends Resource
## 테스트 방 전용 포탑 수치 (패링·완벽 회피 연습용). 실제 값은 res://data/props/test_turret.tres
## M3 의 원거리형 적이 생기면 튜토리얼에는 쓰지 않는다.

## 발사 간격 (틱)
@export var fire_interval_ticks: int = 0
## 플레이어가 이 거리(px) 안에 있을 때만 쏜다
@export var fire_range: float = 0.0
## 몸통(벽 판정) 한 변 길이, 탄이 나오는 거리 (px)
@export var body_size: float = 0.0
@export var muzzle_offset: float = 0.0
@export var projectile: ProjectileData
