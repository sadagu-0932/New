class_name Combo
extends RefCounted
## 연속 퍼펙트 콤보 (숨은 테크 4). 완벽 패링·완벽 회피가 이어지면 단계가 오른다.
## 숫자 UI 없음 — 플레이어 주변 이펙트로만 보여준다. 게임 안 안내 금지.

var stage: int = 0
var _timer: int = 0
var _data: AdvancedTechData


func _init(data: AdvancedTechData) -> void:
	_data = data


## 완벽 판정 성공
func add() -> void:
	stage = mini(stage + 1, _data.combo_max_stage)
	_timer = _data.combo_window_ticks
	Events.combo_changed.emit(stage)


func tick() -> void:
	if stage <= 0:
		return
	_timer -= 1
	if _timer <= 0:
		reset()


func reset() -> void:
	if stage == 0:
		return
	stage = 0
	_timer = 0
	Events.combo_changed.emit(0)


func speed_mult() -> float:
	return 1.0 + _data.combo_speed_bonus * stage


func damage_mult() -> float:
	return 1.0 + _data.combo_damage_bonus * stage
