class_name HitInfo
extends RefCounted
## 공격 한 번의 정보 (피격 쪽에 전달)

enum Kind { BULLET, MELEE, REFLECT, EXECUTE }

var damage: int = 0
var kind: Kind = Kind.BULLET
var team: int = Team.PLAYER
var direction: Vector2 = Vector2.ZERO
var source: Node = null
## 완벽 패링으로 강화된 반사탄인지
var perfect: bool = false


static func make(damage_value: int, kind_value: Kind, team_value: int, dir: Vector2, src: Node) -> HitInfo:
	var h := HitInfo.new()
	h.damage = damage_value
	h.kind = kind_value
	h.team = team_value
	h.direction = dir
	h.source = src
	return h
