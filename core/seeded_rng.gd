class_name SeededRng
extends RefCounted
## 고정 시드 RNG. 게임 로직의 랜덤은 전부 Game.rng 하나로만 뽑는다 (리플레이 결정론).
## 연출용(화면 흔들림 등) 랜덤도 로직에 영향이 없으면 별도 인스턴스를 써도 되지만,
## 로직에 영향을 주는 값은 반드시 Game.rng 를 쓴다.

var _rng := RandomNumberGenerator.new()


func reset(seed_value: int) -> void:
	_rng.seed = seed_value


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func get_state() -> int:
	return _rng.state


func set_state(value: int) -> void:
	_rng.state = value
