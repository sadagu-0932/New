class_name SpreaderData
extends EnemyData
## 탄막형 수치. 실제 값은 res://data/enemies/spreader*.tres

@export var projectile: ProjectileData
## 한 번에 원형으로 뿌리는 탄 수
@export var bullets_per_volley: int = 0
## 발사 간격 (틱)
@export var fire_interval_ticks: int = 0
@export var first_shot_delay_ticks: int = 0
@export var telegraph_ticks: int = 0
## 발사할 때마다 원 전체를 이만큼 돌린다 (도) → 나선형 탄막
@export var rotation_step_deg: float = 0.0
@export var muzzle_offset: float = 0.0
