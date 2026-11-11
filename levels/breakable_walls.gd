class_name BreakableWalls
extends Node
## 베어 낼 수 있는 벽 (나무). 그 칸이 든 구역(없으면 들판)의 breakable_walls 가 켜져 있어야 벨 수 있다
## (숲·들판의 나무는 되고, 연구소 벽·마을 집은 안 된다).
## 근접 공격(총으로 후려치기) 판정이 닿은 나무 칸은 몇 번 맞으면 베어져 지나갈 수 있게 된다.
##  - 맵 테두리 칸은 베어지지 않는다 (맵 밖으로 나가지 않게)
##  - 한 번 휘두를 때 같은 칸은 한 번만 맞는다
##  - 벤 자리는 그루터기가 남고, 지역에 다시 들어오면 나무는 다시 자라 있다
## 필요한 횟수·떨어지는 아이템은 지역 데이터

var level: Level
var area: AreaData
## 칸 → 지금까지 맞은 횟수
var _hits: Dictionary = {}
## 칸 → 마지막으로 맞은 휘두르기 번호
var _last_swing: Dictionary = {}


func _init(owner_level: Level, area_data: AreaData) -> void:
	level = owner_level
	area = area_data


## 벨 수 있는 칸인지
func can_break(cell: Vector2i) -> bool:
	var m := level.map
	return m.is_wall(cell) and area.breakable_at(cell) \
		and cell.x > 0 and cell.y > 0 and cell.x < m.width - 1 and cell.y < m.height - 1


func _physics_process(_delta: float) -> void:
	var player := level.player
	if player == null or player.is_dead() or not player.melee.is_active():
		return
	var melee := player.melee
	var center := melee.global_position
	var radius := melee.data.radius
	var from := Vector2i(((center - Vector2.ONE * radius) / LevelMap.TILE_SIZE).floor())
	var to := Vector2i(((center + Vector2.ONE * radius) / LevelMap.TILE_SIZE).floor())
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			var cell := Vector2i(x, y)
			if not can_break(cell) or int(_last_swing.get(cell, -1)) == melee.swing_id:
				continue
			# 원(근접 판정)과 칸(네모)이 닿는지
			var rect := Rect2(Vector2(cell * LevelMap.TILE_SIZE), Vector2.ONE * LevelMap.TILE_SIZE)
			var nearest := center.clamp(rect.position, rect.end)
			if nearest.distance_to(center) > radius:
				continue
			_last_swing[cell] = melee.swing_id
			hit(cell)


## 칸을 한 번 친다. 베어졌으면 true
func hit(cell: Vector2i) -> bool:
	if not can_break(cell):
		return false
	_hits[cell] = int(_hits.get(cell, 0)) + 1
	var pos := LevelMap.cell_center(cell)
	Effect.spawn(&"hit_enemy", pos)
	Audio.play("melee_hit")
	if int(_hits[cell]) < maxi(area.break_hits, 1):
		return false
	_break(cell)
	return true


func _break(cell: Vector2i) -> void:
	var m := level.map
	var row := m.rows[cell.y]
	m.rows[cell.y] = row.substr(0, cell.x) + "." + row.substr(cell.x + 1)
	_hits.erase(cell)
	# 그 칸은 그루터기, 둘레 칸은 가장자리 그림을 다시 고른다
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := cell + Vector2i(dx, dy)
			LevelBuilder.paint(level.tiles, m, c, c == cell)
	Effect.spawn(&"enemy_death", LevelMap.cell_center(cell))
	Events.wall_broken.emit(cell)
	if not area.break_drop_item.is_empty():
		Story.inventory.add(area.break_drop_item)
