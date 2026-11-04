class_name ShockwaveSkill
extends Skill
## 충격파: 주변의 적 탄을 모두 없애고 적을 밀쳐낸다. 안정형 (초보 추천).


func _sd() -> ShockwaveData:
	return data as ShockwaveData


func _activate() -> bool:
	var d := _sd()
	var center := player.global_position
	var r2 := d.radius * d.radius
	for node in player.get_tree().get_nodes_in_group(Projectile.GROUP_ENEMY):
		var p := node as Projectile
		if p and p.alive and p.global_position.distance_squared_to(center) <= r2:
			p.destroy(true)
	for node in player.get_tree().get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e == null or e.dead:
			continue
		var to := e.global_position - center
		if to.length_squared() <= r2:
			var dir := to.normalized() if to != Vector2.ZERO else Vector2.RIGHT
			if d.damage > 0:
				e.hurtbox.receive_hit(HitInfo.make(d.damage, HitInfo.Kind.MELEE, Team.PLAYER, dir, player))
			if not e.dead:
				e.apply_knockback(dir * d.knockback_speed, d.knockback_ticks)
	Effect.spawn(&"shockwave", center, 0.0, d.radius * 2.0 / 16.0, "skill_fx")
	return true
