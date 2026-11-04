class_name GolemData
extends EnemyData
## 탄막 골렘 수치. 실제 값은 res://data/bosses/golem.tres
## 공통 적 수치(체력·크기·시야 등)는 EnemyData 에 있다.

@export_group("등장")
## 7구간에 들어온 뒤 공격을 시작할 때까지 틱
@export var intro_ticks: int = 0

@export_group("피격")
## 몸통은 일반 공격에 거의 안 맞는다: 이 횟수만큼 맞아야 1 데미지
@export var body_hits_per_damage: int = 1
## 반사탄이 코어에 줄 때 곱하는 배율
@export var core_damage_mult: float = 1.0
## 완벽 패링 반사탄을 이 횟수만큼 연속으로 맞히면 그로기
@export var groggy_perfect_hits: int = 0
## 연속으로 인정하는 간격 (틱). 이보다 늦으면 다시 1부터
@export var groggy_chain_window_ticks: int = 0
## 그로기 지속 틱 (공격 안 함, 모든 공격이 코어에 들어감)
@export var groggy_ticks: int = 0
## 그로기 중 모든 공격 데미지 배율
@export var groggy_damage_mult: float = 1.0

@export_group("패턴")
## 패턴 사이 쉬는 틱
@export var rest_ticks: int = 0
## 패턴이 쓰는 탄
@export var projectile: ProjectileData
## 탄이 나오는 거리 (몸 중심에서 px)
@export var muzzle_offset: float = 0.0
## 패턴 1: 원형 연발 (탄 수, 연발 횟수, 연발 간격, 연발마다 회전 도)
@export var ring_bullets: int = 0
@export var ring_volleys: int = 0
@export var ring_interval_ticks: int = 0
@export var ring_rotation_deg: float = 0.0
## 패턴 2: 조준 부채꼴 (탄 수, 퍼짐 각도 도, 연발 횟수, 간격) — 패링 연습용 느린 탄
@export var fan_bullets: int = 0
@export var fan_spread_deg: float = 0.0
@export var fan_volleys: int = 0
@export var fan_interval_ticks: int = 0
## 패턴 3: 나선 (지속 틱, 발사 간격, 팔 수, 발사마다 회전 도)
@export var spiral_ticks: int = 0
@export var spiral_interval_ticks: int = 0
@export var spiral_arms: int = 0
@export var spiral_rotation_deg: float = 0.0
## 2페이즈(본편) 패턴 속도 배율. 데모에서는 쓰지 않음
@export var phase2_speed_mult: float = 1.0

@export_group("컷씬")
## 2페이즈 시작 컷씬 단계별 틱: 각성 / 필살기 / 쓰러짐 / 암전 / TO BE CONTINUED
@export var cut_awaken_ticks: int = 0
@export var cut_special_ticks: int = 0
@export var cut_collapse_ticks: int = 0
@export var cut_fade_ticks: int = 0
@export var cut_text_ticks: int = 0
## 필살기 연출에 뿌리는 탄 수 (화면 연출 전용, 판정 없음)
@export var cut_special_bullets: int = 0
