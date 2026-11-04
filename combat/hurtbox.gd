class_name Hurtbox
extends HitArea
## 피격 영역. 공격 쪽(탄·근접)이 직접 찾아서 receive_hit() 을 부른다.
## 실제 처리(데미지·무적·완벽 회피 판정)는 주인이 handler 로 정한다.

enum Result {
	HIT,      ## 맞음 (탄은 관통이 아니면 사라짐)
	IGNORED,  ## 무시됨 (무적 등, 탄은 그대로 지나감)
}

## func(hit: HitInfo) -> Result
var handler: Callable


func _init() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0


func receive_hit(hit: HitInfo) -> Result:
	if handler.is_valid():
		return handler.call(hit) as Result
	return Result.HIT
