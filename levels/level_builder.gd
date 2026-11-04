class_name LevelBuilder
extends RefCounted
## LevelMap → 타일맵 노드. 타일셋도 코드로 만든다 (에디터 없이 수정 가능하게).
## 바닥 레이어(충돌 없음) + 벽 레이어(충돌 있음) 두 장.

const SOURCE_ID := 0


static func build(map: LevelMap, theme: ThemeData) -> Node2D:
	var root := Node2D.new()
	root.name = "Tiles"
	var meta := theme.load_json("tiles")
	var tile_set := _build_tile_set(theme.load_texture("tiles"), meta)
	var tiles: Dictionary = meta.get("tiles", {})

	var floor_layer := TileMapLayer.new()
	floor_layer.name = "Floor"
	floor_layer.tile_set = tile_set
	floor_layer.collision_enabled = false
	root.add_child(floor_layer)

	var wall_layer := TileMapLayer.new()
	wall_layer.name = "Walls"
	wall_layer.tile_set = tile_set
	root.add_child(wall_layer)

	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			if map.is_floor(cell):
				# 금 간 바닥은 칸 좌표로 정한다 (게임 RNG를 쓰지 않음)
				var cracked := (x * 7 + y * 13) % 11 == 0
				floor_layer.set_cell(cell, SOURCE_ID, _coords(tiles, "floor_alt" if cracked else "floor"))
			elif map.is_wall(cell):
				# 아래가 바닥이면 벽 앞면, 아니면 벽 윗면
				var face := map.is_floor(cell + Vector2i.DOWN)
				wall_layer.set_cell(cell, SOURCE_ID, _coords(tiles, "wall_face" if face else "wall_top"))
	return root


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
		if tile_name.begins_with("wall"):
			var tile_data := source.get_tile_data(coords, 0)
			tile_data.add_collision_polygon(0)
			tile_data.set_collision_polygon_points(0, 0, square)
	return tile_set
