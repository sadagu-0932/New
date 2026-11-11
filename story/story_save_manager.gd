class_name StorySaveManager
extends Node
## 스토리판 저장 관리.
##  - 자동저장: 새 게임 시작 직후(입구) / 일정 시간마다 검사해 좌표나 인벤토리가 변했으면 / 웨이스톤 활성화 때
##  - 수동 저장: 일시정지 메뉴의 저장
##  - 전투 중·보스방에서는 자동·수동 모두 저장하지 않는다 (CombatState)
## 주기·기준은 data/save.tres

## 지금 진행 중인 런 (StoryMain 이 넣어 준다)
var run: RunController

var _ticks: int = 0
## 마지막 저장 때의 지역·위치·인벤토리 (변화 비교용)
var _last_area: String = ""
var _last_pos: Vector2 = Vector2.ZERO
var _last_inventory: String = ""
var _has_last: bool = false


func _player() -> Player:
	return run.level.player if run != null and run.level != null else null


## 지금 저장할 수 있는지
func can_save() -> bool:
	var p := _player()
	return p != null and not p.is_dead() and not p.cutscene_lock and not CombatState.is_restricted(get_tree())


## 지금 상태를 저장 내용으로
func capture() -> Dictionary:
	var p := _player()
	return {
		"pos": [p.global_position.x, p.global_position.y],
		"hp": p.health.current,
		"ammo": p.ammo.current,
		"story": Story.to_dict(),
	}


func save_manual() -> bool:
	if not can_save() or not StorySave.write_manual(capture()):
		Events.toast.emit(DB.save.text_cannot_save)
		return false
	_remember()
	Events.toast.emit(DB.save.text_saved_manual)
	return true


## reason: "start"(새 게임 입구) · "timer"(주기 검사) · "waystone"
func save_auto(_reason: String = "") -> bool:
	if not can_save() or not StorySave.write_auto(capture()):
		return false
	_remember()
	Events.toast.emit(DB.save.text_saved_auto)
	return true


## 불러온 직후: 그 저장을 "마지막 저장"으로 기억하고 주기를 처음부터 센다
func mark_loaded(state: Dictionary) -> void:
	var pos: Array = state.get("pos", [0.0, 0.0])
	_last_area = Story.area
	_last_pos = Vector2(float(pos[0]), float(pos[1]))
	_last_inventory = Story.inventory_signature()
	_has_last = true
	_ticks = 0


func _remember() -> void:
	_last_area = Story.area
	_last_pos = _player().global_position
	_last_inventory = Story.inventory_signature()
	_has_last = true
	_ticks = 0


## 마지막 저장 이후 좌표나 인벤토리가 변했는지
func has_changed() -> bool:
	var p := _player()
	if p == null:
		return false
	if not _has_last or _last_area != Story.area or _last_inventory != Story.inventory_signature():
		return true
	return p.global_position.distance_to(_last_pos) > DB.save.min_move_distance


func interval_ticks() -> int:
	return int(DB.save.autosave_interval_seconds * Game.config.tick_rate)


func _physics_process(_delta: float) -> void:
	if run == null:
		return
	_ticks += 1
	if _ticks < interval_ticks():
		return
	# 검사 시점에 전투 중이면 끝날 때까지 미뤘다가 검사한다
	if not can_save():
		return
	if has_changed():
		save_auto("timer")
	else:
		_ticks = 0
