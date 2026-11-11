class_name StatMod
extends Resource
## 장착 효과 한 줄: 스탯 하나를 더하거나 곱한다.
## 최종값 = (기본값 + 모든 ADD 의 합) × 모든 MUL 의 곱   (Loadout.stat)
## 쓸 수 있는 스탯 이름 (플레이어가 읽는 것):
##   max_hp            최대 체력 (칸)
##   move_speed        이동 속도
##   hurt_invuln_ticks 피격 후 무적 틱
##   ranged_damage     사격 데미지 배율 (기본 1)
##   melee_damage      근접·반사탄 데미지 배율 (기본 1)
## 화면에 보일 이름은 data/inventory.tres 의 stat_names

enum Op { ADD, MUL }

@export var stat: String = ""
@export var op: Op = Op.ADD
@export var value: float = 0.0
