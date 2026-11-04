class_name StealthData
extends Resource
## 완벽 회피·투명 수치. 실제 값은 res://data/stealth.tres

## 완벽 회피 판정창: 회피 시작 후 이 틱 수 안에 공격이 닿으면 완벽
@export var perfect_dodge_window_ticks: int = 0
## 판정창 동안 적 탄이 (피격 반지름 + 탄 반지름 + 이 값) 안으로 스치면 완벽 회피 (px)
## 옆으로 피해서 탄과 겹치지 않아도 "피격 직전에 피함"으로 인정하기 위한 여유
@export var perfect_dodge_margin: float = 0.0
## 완벽 회피 후 투명 지속 틱
@export var stealth_ticks: int = 0
