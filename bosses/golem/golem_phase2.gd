class_name GolemPhase2
extends GolemPhase
## 2페이즈: 동력이 바닥난 골렘. 탄막이 성기고 중간중간 길게 멈칫한다 → 짧은 전투.
## 패턴은 정해진 순서로 돈다 (조준탄 → 조준탄 → 성긴 원형). 랜덤을 쓰지 않는다.
## 몸통은 여전히 일반 탄에 거의 안 깎이고, 반사탄으로 코어를 부수면 붕괴한다 (Golem._defeat).
## 수치는 GolemData 의 p2_* (data/bosses/golem.tres, 지역용은 data/enemies/golem_worn.tres)

enum Pattern { AIMED, RING }

const SEQUENCE: Array[int] = [Pattern.AIMED, Pattern.AIMED, Pattern.RING]

var pattern: int = -1
## 패턴 기록 (테스트용)
var history: Array[int] = []
var _step: int = 0
var _rest: int = 0
var _timer: int = 0
var _count: int = 0


func number() -> int:
	return 2


func enter() -> void:
	pattern = -1
	_rest = golem.gd().p2_rest_ticks


func is_attacking() -> bool:
	return pattern >= 0


func tick() -> void:
	var d := golem.gd()
	if pattern < 0:
		_rest -= 1
		if _rest <= 0:
			pattern = SEQUENCE[_step % SEQUENCE.size()]
			_step += 1
			history.append(pattern)
			_timer = 0
			_count = 0
		return
	_timer -= 1
	if _timer > 0:
		return
	match pattern:
		Pattern.AIMED:
			golem.fire(golem.dir_to_target())
			_count += 1
			_timer = d.p2_aimed_interval_ticks
			if _count >= d.p2_aimed_shots:
				_finish()
		Pattern.RING:
			var n := maxi(d.p2_ring_bullets, 1)
			for i in n:
				golem.fire(golem.dir_to_target().rotated(TAU * i / n))
			_finish()


func _finish() -> void:
	pattern = -1
	_rest = golem.gd().p2_rest_ticks
