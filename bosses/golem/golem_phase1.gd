class_name GolemPhase1
extends GolemPhase
## 1페이즈: 패턴 3종(원형 연발 / 조준 부채꼴 / 나선)을 쉬는 시간을 사이에 두고 반복.
## 다음 패턴은 Game.rng(고정 시드)로 고르되 같은 패턴을 연달아 쓰지 않는다 → 매 판 같은 순서.

enum Pattern { RING, FAN, SPIRAL }

## 2페이즈(본편)에서 속도를 올릴 때 쓰는 배율 (간격을 나눔)
var speed_mult: float = 1.0
var pattern: int = -1
var last_pattern: int = -1
## 패턴 기록 (테스트·리플레이 확인용)
var history: Array[int] = []

var _rest: int = 0
var _timer: int = 0
var _count: int = 0
var _angle: float = 0.0


func number() -> int:
	return 1


func enter() -> void:
	pattern = -1
	_rest = _scaled(golem.gd().rest_ticks)


func is_attacking() -> bool:
	return pattern >= 0


func tick() -> void:
	if pattern < 0:
		_rest -= 1
		if _rest <= 0:
			_start_next()
		return
	match pattern:
		Pattern.RING:
			_tick_ring()
		Pattern.FAN:
			_tick_fan()
		Pattern.SPIRAL:
			_tick_spiral()


func _scaled(ticks: int) -> int:
	return maxi(1, roundi(ticks / speed_mult))


func _start_next() -> void:
	var choices: Array[int] = []
	for p: int in Pattern.values():
		if p != last_pattern:
			choices.append(p)
	pattern = choices[Game.rng.randi_range(0, choices.size() - 1)]
	last_pattern = pattern
	history.append(pattern)
	_timer = 0
	_count = 0
	_angle = 0.0


func _finish() -> void:
	pattern = -1
	_rest = _scaled(golem.gd().rest_ticks)


func _tick_ring() -> void:
	var d := golem.gd()
	_timer -= 1
	if _timer > 0:
		return
	var step := TAU / d.ring_bullets
	for i in d.ring_bullets:
		golem.fire(Vector2.RIGHT.rotated(_angle + step * i))
	_angle += deg_to_rad(d.ring_rotation_deg)
	_count += 1
	_timer = _scaled(d.ring_interval_ticks)
	if _count >= d.ring_volleys:
		_finish()


func _tick_fan() -> void:
	var d := golem.gd()
	_timer -= 1
	if _timer > 0:
		return
	var aim := golem.dir_to_target()
	var spread := deg_to_rad(d.fan_spread_deg)
	for i in d.fan_bullets:
		var t := 0.0 if d.fan_bullets <= 1 else float(i) / float(d.fan_bullets - 1) - 0.5
		golem.fire(aim.rotated(spread * t))
	_count += 1
	_timer = _scaled(d.fan_interval_ticks)
	if _count >= d.fan_volleys:
		_finish()


func _tick_spiral() -> void:
	var d := golem.gd()
	_count += 1
	if _count % _scaled(d.spiral_interval_ticks) == 0:
		var step := TAU / d.spiral_arms
		for i in d.spiral_arms:
			golem.fire(Vector2.RIGHT.rotated(_angle + step * i))
		_angle += deg_to_rad(d.spiral_rotation_deg)
	if _count >= _scaled(d.spiral_ticks):
		_finish()
