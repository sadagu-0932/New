class_name AdvancedTechData
extends Resource
## 고급 테크닉 수치. 실제 값은 res://data/advanced_tech.tres
## ※ 이 테크닉들은 게임 안 어디에도 안내하지 않는다 (CLAUDE.md "숨은 고급 테크닉"). 문서·코드 주석에만 기록.
##   1. 은신 처형: 투명 상태에서 적에게 붙어 E → 큰 데미지 + 탄약 대량 흡수 (투명은 풀림)
##   2. 반사탄 재패링: 반사된 탄을 새로 휘두른 근접으로 다시 치면 연쇄 강화 (최대 단계 제한)
##   3. 돌진 베기: 회피 중 근접 → 회피 이동 거리만큼 돌진하며 베기 (돌진 중 무적)
##   4. 연속 퍼펙트 콤보: 완벽 패링·완벽 회피를 일정 시간 안에 이어가면 단계 상승 → 이동속도·데미지 증가.
##      시간 안에 못 이으면 초기화. 숫자 UI 없이 캐릭터 주변 이펙트로만 표시

@export_group("은신 처형")
## 이 거리(px) 안의 적에게 처형 가능
@export var execute_range: float = 0.0
@export var execute_damage: int = 0
## 처형 시 흡수하는 탄약
@export var execute_ammo: int = 0

@export_group("반사탄 재패링")
## 다시 칠 수 있는 최대 횟수 (첫 반사 이후)
@export var reparry_max_chain: int = 0
## 다시 칠 때마다 더해지는 데미지
@export var reparry_damage_bonus: int = 0
## 다시 칠 때마다 곱해지는 속도
@export var reparry_speed_mult: float = 1.0
## 다시 칠 때마다 커지는 판정 반지름 (px)
@export var reparry_radius_bonus: float = 0.0

@export_group("돌진 베기")
## 돌진에 걸리는 틱 (거리 = 회피 이동 거리)
@export var dash_slash_ticks: int = 0
@export var dash_slash_invuln: bool = true

@export_group("연속 퍼펙트 콤보")
@export var combo_max_stage: int = 0
## 다음 완벽 판정까지 허용 시간 (틱). 넘기면 초기화
@export var combo_window_ticks: int = 0
## 단계당 이동속도·데미지 증가 비율
@export var combo_speed_bonus: float = 0.0
@export var combo_damage_bonus: float = 0.0
