class_name LevelBuilder
extends RefCounted
## LevelMap → 타일맵 노드. 타일셋도 코드로 만든다 (에디터 없이 수정 가능하게).
## 바닥 레이어(충돌 없음) + 벽 레이어(벽: WORLD 충돌, 구덩이: PIT 충돌) 두 장.
##
## 타일셋(이름.json 의 tiles)에 아래 이름이 있으면 골라 쓰고, 없으면 기본 타일로 돌아간다:
##   바닥   floor · floor_alt · floor_alt2 · floor_alt3 (칸 좌표로 섞음) · floor_shadow (벽 바로 아래 칸)
##          floor_stump (베어 낸 나무 자리)
##   벽 윗면 wall_top + 열린 쪽 글자 n·s·w·e (예: wall_top_nw). s = 바로 아래가 벽 앞면(처마)
##   벽 앞면 wall_face · wall_face_l · wall_face_r (줄의 양 끝) · wall_face_door (줄 가운데) · wall_face_window
##          wall_face_alt1~3 (문이 없는 타일셋에서 칸 좌표로 섞음)
##   meta "wall_over_floor": true 면 벽 칸 밑에도 바닥을 깐다 (나무처럼 가장자리가 뚫린 그림용)

const SOURCE_ID := 0
const FLOOR := "Floor"
const WALLS := "Walls"


static func build(map: LevelMap, theme: ThemeData, tileset: String = "tiles") -> Node2D:
	var root := Node2D.new()
	root.name = "Tiles"
	var meta := theme.load_json(tileset)
	var tile_set := _build_tile_set(theme.load_texture(tileset), meta)
	root.set_meta(&"tiles", meta.get("tiles", {}))
	root.set_meta(&"wall_over_floor", bool(meta.get("wall_over_floor", false)))

	var floor_layer := TileMapLayer.new()
	floor_layer.name = FLOOR
	floor_layer.tile_set = tile_set
	floor_layer.collision_enabled = false
	root.add_child(floor_layer)

	var wall_layer := TileMapLayer.new()
	wall_layer.name = WALLS
	wall_layer.tile_set = tile_set
	root.add_child(wall_layer)

	for y in map.height:
		for x in map.width:
			paint(root, map, Vector2i(x, y))
	return root


## 칸 하나를 (다시) 그린다. 맵이 바뀌었을 때(나무를 벰) 그 칸과 둘레 칸에 부른다
static func paint(root: Node2D, map: LevelMap, cell: Vector2i, stump: bool = false) -> void:
	var tiles: Dictionary = root.get_meta(&"tiles")
	var floor_layer := root.get_node(FLOOR) as TileMapLayer
	var wall_layer := root.get_node(WALLS) as TileMapLayer
	var x := cell.x
	var y := cell.y
	if map.is_floor(cell):
		wall_layer.erase_cell(cell)
		floor_layer.set_cell(cell, SOURCE_ID, _coords(tiles, _floor_name(tiles, map, cell, stump)))
	elif map.is_wall(cell):
		if bool(root.get_meta(&"wall_over_floor")):
			floor_layer.set_cell(cell, SOURCE_ID, _coords(tiles, "floor"))
		wall_layer.set_cell(cell, SOURCE_ID, _coords(tiles, _wall_name(tiles, map, cell)))
	elif map.is_pit(cell):
		wall_layer.set_cell(cell, SOURCE_ID, _coords(tiles, "pit"))
	else:
		wall_layer.erase_cell(Vector2i(x, y))


static func _floor_name(tiles: Dictionary, map: LevelMap, cell: Vector2i, stump: bool) -> String:
	if stump and tiles.has("floor_stump"):
		return "floor_stump"
	if tiles.has("floor_shadow") and map.is_wall(cell + Vector2i.UP):
		return "floor_shadow"
	# 바닥 무늬는 칸 좌표로 정한다 (게임 RNG 를 쓰지 않음)
	var h := (cell.x * 7 + cell.y * 13) % 11
	if h == 0:
		return "floor_alt"
	if h == 4 and tiles.has("floor_alt2"):
		return "floor_alt2"
	if h == 8 and tiles.has("floor_alt3"):
		return "floor_alt3"
	return "floor"


## 벽 앞면인지: 벽이고 바로 아래가 바닥
static func _is_face(map: LevelMap, cell: Vector2i) -> bool:
	return map.is_wall(cell) and map.is_floor(cell + Vector2i.DOWN)


static func _wall_name(tiles: Dictionary, map: LevelMap, cell: Vector2i) -> String:
	if _is_face(map, cell):
		return _face_name(tiles, map, cell)
	# 윗면: 열린 쪽(벽이 아닌 쪽)에 따라 가장자리 그림을 고른다
	var suffix := ""
	if not map.is_wall(cell + Vector2i.UP):
		suffix += "n"
	if _is_face(map, cell + Vector2i.DOWN):
		suffix += "s"
	if not map.is_wall(cell + Vector2i.LEFT):
		suffix += "w"
	if not map.is_wall(cell + Vector2i.RIGHT):
		suffix += "e"
	var tile_name := "wall_top_%s" % suffix
	return tile_name if not suffix.is_empty() and tiles.has(tile_name) else "wall_top"


static func _face_name(tiles: Dictionary, map: LevelMap, cell: Vector2i) -> String:
	# 옆으로 이어진 앞면 줄에서 몇 번째인지
	var left := 0
	while _is_face(map, cell + Vector2i.LEFT * (left + 1)):
		left += 1
	var right := 0
	while _is_face(map, cell + Vector2i.RIGHT * (right + 1)):
		right += 1
	var length := left + right + 1
	if tiles.has("wall_face_door") and length >= 3:
		# 집: 줄 가운데에 문, 문에서 한 칸 건너마다 창문
		var door := (length - 1) / 2
		if left == door:
			return "wall_face_door"
		if left > 0 and right > 0 and absi(left - door) % 2 == 0 and tiles.has("wall_face_window"):
			return "wall_face_window"
	elif not tiles.has("wall_face_door"):
		var h := (cell.x * 5 + cell.y * 3) % 7
		for i in 3:
			if h == i * 2 + 1 and tiles.has("wall_face_alt%d" % (i + 1)):
				return "wall_face_alt%d" % (i + 1)
	if left == 0 and length > 1 and tiles.has("wall_face_l"):
		return "wall_face_l"
	if right == 0 and length > 1 and tiles.has("wall_face_r"):
		return "wall_face_r"
	return "wall_face"


static func _coords(tiles: Dictionary, tile_name: String) -> Vector2i:
	var c: Array = tiles.get(tile_name, [0, 0])
	return Vector2i(int(c[0]), int(c[1]))


static func _build_tile_set(texture: Texture2D, meta: Dictionary) -> TileSet:
	var size := int(meta.get("tile_size", LevelMap.TILE_SIZE))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(size, size)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, Layers.WORLD)
	tile_set.set_physics_layer_collision_mask(0, 0)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(1, Layers.PIT)
	tile_set.set_physics_layer_collision_mask(1, 0)

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(size, size)
	tile_set.add_source(source, SOURCE_ID)

	var half := size * 0.5
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	])
	var tiles: Dictionary = meta.get("tiles", {})
	for tile_name: String in tiles:
		var coords := _coords(tiles, tile_name)
		source.create_tile(coords)
		var physics_layer := -1
		if tile_name.begins_with("wall"):
			physics_layer = 0
		elif tile_name == "pit":
			physics_layer = 1
		if physics_layer >= 0:
			var tile_data := source.get_tile_data(coords, 0)
			tile_data.add_collision_polygon(physics_layer)
			tile_data.set_collision_polygon_points(physics_layer, 0, square)
	return tile_set
