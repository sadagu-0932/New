class_name WeaponData
extends Resource
## 원거리 무기 하나의 전투 수치. 근접 공격은 이 무기로 후려치는 동작이라
## 근접·패링 성능(범위·속도·데미지)도 무기마다 여기 들어 있다. 별도의 근접 무기는 없다.

## 사격: 탄창·연사·탄
@export var gun: GunData
## 근접: 판정 시간·범위·데미지
@export var melee: MeleeData
## 패링: 반사탄·완벽 판정
@export var parry: ParryData
