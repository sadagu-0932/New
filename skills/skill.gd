class_name Skill
extends Node2D
## 스킬 베이스. 플레이어의 자식으로 붙는다. Q(InputFrame.SKILL)로 쓴다.
## 매 틱 플레이어가 tick() 을 부르고, 쓸 때 try_use() 를 부른다.

var data: SkillData
var player: Player
var cooldown_left: int = 0


func _init(skill_data: SkillData) -> void:
	data = skill_data


func can_use() -> bool:
	return cooldown_left <= 0


## 쓰기 시도. 실제로 썼으면 true (쿨타임 시작)
func try_use() -> bool:
	if not can_use():
		return false
	if not _activate():
		return false
	cooldown_left = data.cooldown_ticks
	Events.skill_used.emit(data.id)
	return true


## 매 틱 (쿨타임, 지속 효과)
func tick() -> void:
	if cooldown_left > 0:
		cooldown_left -= 1
	_tick_effect()


## 쿨타임 진행도 0(막 씀) ~ 1(사용 가능)
func ready_ratio() -> float:
	if data.cooldown_ticks <= 0:
		return 1.0
	return 1.0 - float(cooldown_left) / float(data.cooldown_ticks)


## 이 스킬 때문에 플레이어가 무적인지
func grants_invulnerability() -> bool:
	return false


## 하위 클래스: 발동. 발동하지 못했으면 false (쿨타임 안 씀)
func _activate() -> bool:
	return true


## 하위 클래스: 지속 효과
func _tick_effect() -> void:
	pass


## 하위 클래스: 스킬이 바뀌거나 플레이어가 사라질 때 정리
func cleanup() -> void:
	pass
