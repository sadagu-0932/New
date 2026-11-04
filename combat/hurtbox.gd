class_name Hurtbox
extends HitArea
## 피격 영역. 공격(Hitbox)이 이 영역을 감지한다.
## TODO(M3): 피격 처리·무적 연결


func _init() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
