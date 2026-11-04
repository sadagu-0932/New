class_name Charger
extends Enemy
## 돌진형: 쫓아오다가 가까워지면 잠깐 웅크린 뒤(예고) 일직선으로 돌진한다.
## 돌진 방향은 예고가 끝날 때 마지막으로 본 위치로 정해진다 → 옆으로 피하거나 회피로 흘리기.
## 근접·회피 연습용.

enum State { CHASE, WINDUP, CHARGE, RECOVER }

var state: State = State.CHASE
var _timer: int = 0
var _charge_dir: Vector2 = Vector2.RIGHT


func _cd() -> ChargerData:
	return data as ChargerData


func _tick_ai() -> void:
	var d := _cd()
	match state:
		State.CHASE:
			if not has_target:
				velocity = Vector2.ZERO
				return
			if sees_player and global_position.distance_to(target_pos) <= d.charge_trigger_range:
				state = State.WINDUP
				_timer = d.windup_ticks
				velocity = Vector2.ZERO
				return
			move_to(target_pos, d.move_speed)
		State.WINDUP:
			velocity = Vector2.ZERO
			_timer -= 1
			if _timer <= 0:
				_charge_dir = dir_to_target()
				state = State.CHARGE
				_timer = d.charge_ticks
		State.CHARGE:
			velocity = _charge_dir * d.charge_speed
			_timer -= 1
			# 벽이나 무언가에 부딪히면 멈춤
			if _timer <= 0 or get_slide_collision_count() > 0:
				state = State.RECOVER
				_timer = d.recover_ticks
				velocity = Vector2.ZERO
		State.RECOVER:
			velocity = Vector2.ZERO
			_timer -= 1
			if _timer <= 0:
				state = State.CHASE


func _anim() -> StringName:
	match state:
		State.WINDUP, State.CHARGE:
			return &"attack"
		State.RECOVER:
			return &"idle"
	return super._anim()
