class_name BreakableWalls
extends Node
## 베어 낼 수 있는 벽 (나무). 그 칸의 땅 종류가 지역 데이터의 breakable_grounds 에 들어 있어야 벨 수 있다
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


## 쓰러지는 나무 연출 (화면 표시 전용): 베어 낸 나무 그림이 그루터기를 축으로 옆으로 넘어가며 사라진다
func _spawn_falling_tree(cell: Vector2i, with_top: bool) -> void:
	var tileset := area.tileset_at(cell)
	var meta := DB.theme.load_json(tileset)
	var tiles: Dictionary = meta.get("tiles", {})
	var texture := DB.theme.load_texture(tileset)
	if texture == null or not tiles.has("wall_face"):
		return
	var size := LevelMap.TILE_SIZE
	var pivot := Node2D.new()
	# 그루터기(칸 아래쪽 가운데)를 축으로 넘어간다
	pivot.position = LevelMap.cell_center(cell) + Vector2(0, size * 0.5)
	pivot.z_index = 5
	var parts: Array = [["wall_face", 0]]
	if with_top:
		parts.append(["wall_top", -1])
	for part: Array in parts:
		var coords: Array = tiles.get(part[0], [0, 0])
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(coords[0], coords[1]) * size, Vector2.ONE * size)
		var sprite := Sprite2D.new()
		sprite.texture = atlas
		sprite.position = Vector2(0, -size * 0.5 + int(part[1]) * size)
		pivot.add_child(sprite)
	level.effects.add_child(pivot)
	# 플레이어 반대쪽으로 넘어간다
	var away := 1.0
	if level.player != null and level.player.global_position.x > pivot.position.x:
		away = -1.0
	var tween := pivot.create_tween()
	tween.set_parallel(true)
	tween.tween_property(pivot, "rotation", away * PI * 0.5, DB.feel.tree_fall_seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(pivot, "modulate:a", 0.0, DB.feel.tree_fall_seconds * 0.5).set_delay(DB.feel.tree_fall_seconds * 0.6)
	tween.chain().tween_callback(pivot.queue_free)


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
	# 나무 한 그루 = 줄기 칸 + 바로 위의 수관(잎) 칸. 줄기를 베면 위의 잎도 함께 쓰러진다
	# (잎만 남아 공중에 뜬 줄기처럼 보이지 않게)
	var cells: Array[Vector2i] = [cell]
	var top := cell + Vector2i.UP
	if m.is_floor(cell + Vector2i.DOWN) and can_break(top) and not m.is_floor(top + Vector2i.UP):
		cells.append(top)
	for c in cells:
		var row := m.rows[c.y]
		m.rows[c.y] = row.substr(0, c.x) + "." + row.substr(c.x + 1)
		_hits.erase(c)
	# 그 칸은 그루터기, 둘레 칸은 가장자리 그림을 다시 고른다
	for c in cells:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				LevelBuilder.paint(level.tiles, m, n, n == cell)
	_spawn_falling_tree(cell, cells.size() > 1)
	Effect.spawn(&"enemy_death", LevelMap.cell_center(cell))
	Events.wall_broken.emit(cell)
	if not area.break_drop_item.is_empty():
		Story.inventory.add(area.break_drop_item)
	# 벤 나무에서 탄약을 얻는다 (마석 섞인 나무 진을 탄으로 쓴다는 설정, 임시)
	if area.break_ammo > 0 and level.player != null:
		level.player.ammo.add(area.break_ammo)
