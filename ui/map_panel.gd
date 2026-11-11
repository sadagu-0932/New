class_name MapPanel
extends CanvasLayer
## 지도 화면 (스토리판). 키 하나(기본 M)로 열고, 열려 있는 동안 게임이 멈춘다.
## 지역들이 한 장의 넓은 지도에 이어져 펼쳐지고, 화면보다 넓어서 고른 탑을 따라 지도가 움직인다.
##  - 웨이스톤(탑)을 활성화한 곳의 주변만 밝혀져 있고 나머지는 안개에 가려져 있다.
##    새로 밝혀진 곳은 지도를 열 때 안개가 걷히며 드러난다
##  - 활성화한 탑을 ←→ 로 골라 Enter 로 순간이동 (전투 중·보스방에서는 불가)
## 지역 위치(map_pos, 칸 단위)·색은 data/areas/*.tres, 한 칸 크기는 data/story.tres 의 map_tile_px
# TODO(안드로이드 추가 때): 터치 조작 (끌어서 움직이기)

signal teleport_requested(area_id: String, waystone_id: String)

## 지도가 보이는 창 (화면 좌표)
const VIEW := Rect2(8, 20, 304, 112)
const COLOR_SEA := Color(0.07, 0.07, 0.12)
const COLOR_GRID := Color(1, 1, 1, 0.035)
const COLOR_FOG_A := Color(0.15, 0.14, 0.2)
const COLOR_FOG_B := Color(0.12, 0.11, 0.17)
const COLOR_ROAD := Color(0.85, 0.75, 0.5, 0.7)
const COLOR_TOWER_ON := Color(0.62, 0.89, 0.94)
const COLOR_TOWER_OFF := Color(0.5, 0.48, 0.55)
const COLOR_SELECTED := Color(0.97, 0.78, 0.35)
const NOTICE_SECONDS := 1.6
## 안개가 걷히는 시간 (초), 지도가 고른 탑을 따라가는 빠르기
const REVEAL_SECONDS := 1.2
const PAN_SPEED := 6.0

## 지금 진행 중인 런 (StoryMain 이 넣어 준다)
var run: RunController
var is_open: bool = false
## 고른 탑 (targets 의 번호)
var selected: int = 0
## 순간이동할 수 있는 곳: [{ "area": AreaData, "waystone": WaystoneData, "pos": 지도 좌표(px) }]
var targets: Array[Dictionary] = []
## 지도 왼쪽 위가 화면에서 밀려난 정도 (px)
var camera: Vector2 = Vector2.ZERO

var _root: Control
var _canvas: Control
var _info: Label
var _notice: Label
var _textures: Dictionary = {}
var _fog_texture: ImageTexture
var _was_paused: bool = false
var _notice_left: float = 0.0
var _blink: float = 0.0
var _camera_target: Vector2 = Vector2.ZERO
## 지역 id → 안개 진하기 (1 = 가려짐, 0 = 다 걷힘)
var _fog: Dictionary = {}
var _font: Font


func is_showing() -> bool:
	return is_open


func _ready() -> void:
	layer = 94
	add_to_group(Crosshair.POINTER_GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = UiText.make_label().get_theme_font(&"font")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.07, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var title := UiText.make_label("지도")
	title.position = Vector2(0, 5)
	title.size = Vector2(320, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)
	# 지도 창: 밖으로 나간 부분은 잘린다
	var frame := ColorRect.new()
	frame.color = Color(0.77, 0.54, 0.33, 0.9)
	frame.position = VIEW.position - Vector2.ONE
	frame.size = VIEW.size + Vector2.ONE * 2.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(frame)
	var clip := Control.new()
	clip.position = VIEW.position
	clip.size = VIEW.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(clip)
	_canvas = Control.new()
	_canvas.size = VIEW.size
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_map)
	clip.add_child(_canvas)
	_info = UiText.make_label()
	_info.position = Vector2(0, 138)
	_info.size = Vector2(320, 12)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_color_override(&"font_color", COLOR_SELECTED)
	_root.add_child(_info)
	_notice = UiText.make_label()
	_notice.position = Vector2(0, 152)
	_notice.size = Vector2(320, 12)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override(&"font_color", Color(0.95, 0.5, 0.45))
	_notice.visible = false
	_root.add_child(_notice)
	var help := UiText.make_label("←→ 탑 고르기 · Enter 순간이동 · Esc 닫기")
	help.position = Vector2(0, 165)
	help.size = Vector2(320, 12)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.modulate.a = 0.7
	_root.add_child(help)
	_root.visible = false
	# 안개 무늬 (두 색이 엇갈린 구름결)
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			img.set_pixel(x, y, COLOR_FOG_A if ((x / 2) + (y / 2)) % 2 == 0 else COLOR_FOG_B)
	_fog_texture = ImageTexture.create_from_image(img)


## 지도에 나오는 지역 (왼쪽부터)
static func areas() -> Array[AreaData]:
	var out: Array[AreaData] = []
	for a: AreaData in DB.areas.values():
		if a.on_map:
			out.append(a)
	out.sort_custom(func(a: AreaData, b: AreaData) -> bool:
		return a.map_pos.x < b.map_pos.x or (a.map_pos.x == b.map_pos.x and a.id < b.id))
	return out


## 지도에서 밝혀진 지역 id (활성화한 웨이스톤들이 밝히는 곳)
static func revealed_areas() -> Array[String]:
	var out: Array[String] = []
	for a: AreaData in DB.areas.values():
		for w in a.waystones:
			if not Story.waystones.has(w.id):
				continue
			for id: String in (w.reveals if not w.reveals.is_empty() else ([a.id] as Array[String])):
				if not out.has(id):
					out.append(id)
	return out


static func tile_px() -> int:
	return maxi(DB.story.map_tile_px, 1)


## 지역 안의 칸 → 지도 좌표 (px, 지도 왼쪽 위 기준)
static func world_pos(a: AreaData, cell: Vector2) -> Vector2:
	return (Vector2(a.map_pos) + cell) * tile_px()


## 지역이 지도에서 차지하는 네모 (px)
static func area_rect(a: AreaData) -> Rect2:
	var m := a.level_map()
	return Rect2(world_pos(a, Vector2.ZERO), Vector2(m.width, m.height) * tile_px())


## 지도 전체 크기 (px)
static func world_size() -> Vector2:
	var size := Vector2.ZERO
	for a in areas():
		size = size.max(area_rect(a).end)
	return size + Vector2.ONE * 8.0


## 지도에 보일 지역 이름 (가려진 곳은 이름도 가려진다)
static func area_label(a: AreaData) -> String:
	return a.display_name if revealed_areas().has(a.id) else DB.story.text_unknown_area


func _player() -> Player:
	return run.level.player if run != null and run.level != null else null


func can_open() -> bool:
	var p := _player()
	return p != null and not run.paused and not p.is_dead() and not p.cutscene_lock


func open() -> bool:
	if is_open or not can_open():
		return false
	is_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_notice.visible = false
	_notice_left = 0.0
	_build_targets()
	# 처음 보는 밝혀진 지역은 안개가 걷히는 것부터 보여준다
	var revealed := revealed_areas()
	for a in areas():
		var seen := "map_seen:%s" % a.id
		if not revealed.has(a.id):
			_fog[a.id] = 1.0
		elif Story.has_flag(seen):
			_fog[a.id] = 0.0
		else:
			_fog[a.id] = 1.0
			Story.set_flag(seen)
	_refresh()
	camera = _camera_target
	_root.visible = true
	return true


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	get_tree().paused = _was_paused


func _build_targets() -> void:
	targets = []
	selected = 0
	for a in areas():
		var cells := a.prop_cells("Y")
		for i in a.waystones.size():
			var w := a.waystones[i]
			if not Story.waystones.has(w.id) or i >= cells.size():
				continue
			if a.id == Story.area and _is_nearest(a, i):
				selected = targets.size()
			targets.append({"area": a, "waystone": w, "pos": world_pos(a, Vector2(cells[i]) + Vector2(0.5, 0.5))})


## 지금 지역에서 플레이어와 가장 가까운 탑인지 (지도를 열면 그것이 골라져 있다)
func _is_nearest(a: AreaData, index: int) -> bool:
	var p := _player()
	var cells := a.prop_cells("Y")
	var best := -1
	var best_d := INF
	for i in mini(cells.size(), a.waystones.size()):
		if not Story.waystones.has(a.waystones[i].id):
			continue
		var d := LevelMap.cell_center(cells[i]).distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = i
	return best == index


## 지역 축소판 그림 (지형 색은 지역 데이터)
func _texture(a: AreaData) -> ImageTexture:
	if _textures.has(a.id):
		return _textures[a.id]
	var m := a.level_map()
	var img := Image.create(maxi(m.width, 1), maxi(m.height, 1), false, Image.FORMAT_RGBA8)
	for y in m.height:
		for x in m.width:
			var cell := Vector2i(x, y)
			if m.is_wall(cell):
				# 아래가 바닥인 벽은 조금 밝게 (입체감)
				img.set_pixel(x, y, a.map_wall_color.lightened(0.18) if m.is_floor(cell + Vector2i.DOWN) else a.map_wall_color)
			elif m.is_pit(cell):
				img.set_pixel(x, y, a.map_wall_color.darkened(0.5))
			elif m.is_floor(cell):
				var shade := 0.06 if (x * 7 + y * 13) % 5 == 0 else 0.0
				img.set_pixel(x, y, a.map_floor_color.darkened(shade))
	var tex := ImageTexture.create_from_image(img)
	_textures[a.id] = tex
	return tex


## 지금 위치 (지도 좌표). 지도에 없는 지역이면 null
func _here() -> Variant:
	var area := DB.area(Story.area)
	var p := _player()
	if area == null or not area.on_map or p == null:
		return null
	return world_pos(area, p.global_position / LevelMap.TILE_SIZE)


func _refresh() -> void:
	if targets.is_empty():
		_info.text = DB.story.text_no_waystone
		var here: Variant = _here()
		_set_camera_target(here if here != null else Vector2.ZERO)
	else:
		var t := targets[selected]
		_info.text = "%s · %s" % [(t["area"] as AreaData).display_name, (t["waystone"] as WaystoneData).display_name]
		_set_camera_target(t["pos"])
	_canvas.queue_redraw()


## 그 지점이 창 가운데에 오게 (지도 밖은 보이지 않게 가둔다)
func _set_camera_target(point: Vector2) -> void:
	var limit := (world_size() - VIEW.size).max(Vector2.ZERO)
	_camera_target = (point - VIEW.size * 0.5).clamp(Vector2.ZERO, limit).round()


func _draw_map() -> void:
	var px := float(tile_px())
	var world := world_size()
	_canvas.draw_set_transform(-camera.round())
	_canvas.draw_rect(Rect2(Vector2.ZERO, world.max(VIEW.size + camera)), COLOR_SEA)
	for x in range(0, int(world.x) + 320, 16):
		_canvas.draw_line(Vector2(x, 0), Vector2(x, world.y + 180), COLOR_GRID)
	for y in range(0, int(world.y) + 180, 16):
		_canvas.draw_line(Vector2(0, y), Vector2(world.x + 320, y), COLOR_GRID)
	var list := areas()
	# 지역을 잇는 길 (양쪽이 다 밝혀진 곳만)
	for a in list:
		var exits := a.prop_cells("E")
		for i in mini(exits.size(), a.exits.size()):
			var target := DB.area(a.exits[i].target_area)
			if target == null or not target.on_map or float(_fog.get(a.id, 1.0)) >= 1.0 or float(_fog.get(target.id, 1.0)) >= 1.0:
				continue
			var from := world_pos(a, Vector2(exits[i]) + Vector2(0.5, 0.5))
			var to := world_pos(target, target.spawn_position(a.exits[i].target_spawn) / LevelMap.TILE_SIZE)
			_canvas.draw_dashed_line(from, to, COLOR_ROAD, 1.0, 3.0)
	for a in list:
		var rect := area_rect(a)
		var fog := float(_fog.get(a.id, 1.0))
		if fog < 1.0:
			_canvas.draw_texture_rect(_texture(a), rect, false)
			_canvas.draw_rect(rect.grow(1.0), Color(0, 0, 0, 0.6), false)
		if fog > 0.0:
			# 안개: 지역보다 조금 넓게 덮는다
			_canvas.draw_texture_rect(_fog_texture, rect.grow(3.0), true, Color(1, 1, 1, fog))
		var label := area_label(a) if fog < 0.5 else DB.story.text_unknown_area
		var width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE_SMALL).x
		var at := Vector2(rect.get_center().x - width * 0.5, rect.end.y + 11.0).round()
		_canvas.draw_string(_font, at + Vector2.ONE, label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE_SMALL, Color(0.05, 0.04, 0.08))
		_canvas.draw_string(_font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE_SMALL, Color(1, 1, 1, 1.0 if fog < 0.5 else 0.45))
		# 탑: 밝혀진 지역의 탑은 꺼져 있어도 자리가 보인다
		if fog < 0.5:
			var cells := a.prop_cells("Y")
			for i in mini(cells.size(), a.waystones.size()):
				var on := Story.waystones.has(a.waystones[i].id)
				_draw_tower(world_pos(a, Vector2(cells[i]) + Vector2(0.5, 0.5)), on)
	if not targets.is_empty() and int(_blink * 3.0) % 2 == 0:
		var pos: Vector2 = targets[selected]["pos"]
		_canvas.draw_rect(Rect2(pos + Vector2(-5, -11), Vector2(10, 14)), COLOR_SELECTED, false)
	var here: Variant = _here()
	if here != null:
		var at: Vector2 = here
		_canvas.draw_circle(at, 2.5, Color(0.05, 0.04, 0.08))
		_canvas.draw_circle(at, 1.5, Color.WHITE if int(_blink * 4.0) % 2 == 0 else COLOR_SELECTED)
	_canvas.draw_set_transform(Vector2.ZERO)


## 탑 표시 (밑동이 base 에 오게)
func _draw_tower(base: Vector2, on: bool) -> void:
	var body := Color(0.8, 0.78, 0.84) if on else COLOR_TOWER_OFF
	var p := base.round()
	_canvas.draw_rect(Rect2(p + Vector2(-3, -9), Vector2(6, 11)), Color(0.05, 0.04, 0.08))
	_canvas.draw_rect(Rect2(p + Vector2(-2, -6), Vector2(4, 7)), body)
	_canvas.draw_rect(Rect2(p + Vector2(-2, -8), Vector2(4, 2)), COLOR_TOWER_ON if on else Color(0.3, 0.28, 0.34))


func _process(delta: float) -> void:
	if not is_open:
		return
	_blink += delta
	camera = camera.lerp(_camera_target, clampf(delta * PAN_SPEED, 0.0, 1.0))
	var revealed := revealed_areas()
	for id: String in _fog:
		if revealed.has(id) and float(_fog[id]) > 0.0:
			_fog[id] = maxf(float(_fog[id]) - delta / REVEAL_SECONDS, 0.0)
	_canvas.queue_redraw()
	if _notice_left > 0.0:
		_notice_left -= delta
		_notice.visible = _notice_left > 0.0


func current_notice() -> String:
	return _notice.text if _notice.visible else ""


func _select(i: int) -> void:
	if targets.is_empty():
		return
	selected = posmod(i, targets.size())
	Audio.play("ui_move")
	_refresh()


## 고른 탑으로 순간이동
func confirm() -> void:
	if not is_open or targets.is_empty():
		return
	if CombatState.is_restricted(get_tree()):
		_notice.text = DB.story.text_cannot_teleport
		_notice.visible = true
		_notice_left = NOTICE_SECONDS
		return
	var t := targets[selected]
	Audio.play("ui_confirm")
	close()
	teleport_requested.emit((t["area"] as AreaData).id, (t["waystone"] as WaystoneData).id)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if not is_open:
		if event.is_action_pressed(&"map") and run != null:
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"map") or event.is_action_pressed(&"pause"):
		close()
	elif event.is_action_pressed(&"move_left") or event.is_action_pressed(&"ui_left") \
			or event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
		_select(selected - 1)
	elif event.is_action_pressed(&"move_right") or event.is_action_pressed(&"ui_right") \
			or event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
		_select(selected + 1)
	elif event.is_action_pressed(&"menu_confirm") or event.is_action_pressed(&"dodge"):
		confirm()
	get_viewport().set_input_as_handled()
