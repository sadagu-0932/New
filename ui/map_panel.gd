class_name MapPanel
extends CanvasLayer
## 지도 화면 (스토리판). 키 하나(기본 M)로 열고, 열려 있는 동안 게임이 멈춘다.
## 바깥 세상 한 장이 그대로 넓은 지도가 되고, 화면보다 넓어서 고른 탑을 따라 지도가 움직인다.
##  - 웨이스톤(탑)을 활성화한 곳의 주변만 밝혀져 있고 나머지는 안개에 가려져 있다.
##    새로 밝혀진 곳은 지도를 열 때 안개가 걷히며 드러난다
##  - 활성화한 탑을 ←→ 로 골라 Enter 로 순간이동 (전투 중·보스방에서는 불가)
## 구역의 지형 색은 data/areas/world.tres, 한 칸 크기·밝혀지는 둘레는 data/story.tres 의 map_tile_px·map_reveal_margin
# TODO(안드로이드 추가 때): 터치 조작 (끌어서 움직이기)

signal teleport_requested(waystone_id: String)

## 지도가 보이는 창 (화면 좌표)
const VIEW := Rect2(8, 20, 304, 112)
const COLOR_FOG_A := Color(0.15, 0.14, 0.2)
const COLOR_FOG_B := Color(0.12, 0.11, 0.17)
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
## 순간이동할 수 있는 곳: [{ "waystone": WaystoneData, "cell": 맵 칸, "pos": 지도 좌표(px) }]
var targets: Array[Dictionary] = []
## 지도 왼쪽 위가 화면에서 밀려난 정도 (px)
var camera: Vector2 = Vector2.ZERO

var _root: Control
var _canvas: Control
var _info: Label
var _notice: Label
var _textures: Dictionary = {}
var _was_paused: bool = false
var _notice_left: float = 0.0
var _blink: float = 0.0
var _camera_target: Vector2 = Vector2.ZERO
## 지금 안개, 지난번에 본 안개(걷히는 중), 옛 안개의 진하기 (1 → 0)
var _fog_now: ImageTexture
var _fog_old: ImageTexture
var _fog_fade: float = 0.0
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


## 지금 지역 (지도가 있는 지역이 아니면 null)
static func world() -> AreaData:
	var a := DB.area(Story.area)
	return a if a != null and a.on_map else null


## 지도에서 밝혀진 구역 id (활성화한 웨이스톤들이 밝히는 곳. 따로 정하지 않은 탑은 자기가 선 구역)
static func revealed_zones() -> Array[String]:
	var out: Array[String] = []
	var a := world()
	if a == null:
		return out
	var cells := a.prop_cells("Y")
	for i in mini(cells.size(), a.waystones.size()):
		var w := a.waystones[i]
		if not Story.waystones.has(w.id):
			continue
		var ids: Array[String] = []
		ids.assign(w.reveals)
		if ids.is_empty():
			var z := a.zone_at(cells[i])
			if z != null:
				ids.append(z.id)
		for id in ids:
			if not out.has(id):
				out.append(id)
	return out


## 그 칸이 지도에서 밝혀져 있는지: 밝혀진 구역과 그 둘레(주변 지형)
static func is_revealed(cell: Vector2i, zones: Array[String]) -> bool:
	var a := world()
	if a == null:
		return false
	var margin := DB.story.map_reveal_margin
	for z in a.zones:
		if zones.has(z.id) and z.rect.grow(margin).has_point(cell):
			return true
	return false


static func tile_px() -> int:
	return maxi(DB.story.map_tile_px, 1)


## 맵의 칸 → 지도 좌표 (px, 지도 왼쪽 위 기준)
static func world_pos(cell: Vector2) -> Vector2:
	return cell * tile_px()


## 지도 전체 크기 (px)
static func world_size() -> Vector2:
	var a := world()
	if a == null:
		return Vector2.ZERO
	var m := a.level_map()
	return Vector2(m.width, m.height) * tile_px()


## 지도에 보일 구역 이름 (가려진 곳은 이름도 가려진다)
static func zone_label(z: ZoneData) -> String:
	return z.display_name if revealed_zones().has(z.id) else DB.story.text_unknown_area


func _player() -> Player:
	return run.level.player if run != null and run.level != null else null


func can_open() -> bool:
	var p := _player()
	return p != null and not run.paused and not p.is_dead() and not p.cutscene_lock


func open() -> bool:
	if is_open or not can_open() or world() == null:
		return false
	is_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_notice.visible = false
	_notice_left = 0.0
	_build_targets()
	# 안개: 지난번에 본 모습(옛 안개)에서 지금 모습으로 걷힌다
	var seen: Array[String] = []
	var now := revealed_zones()
	for id in now:
		if Story.has_flag("map_seen:%s" % id):
			seen.append(id)
		Story.set_flag("map_seen:%s" % id)
	_fog_now = _fog_image(now)
	_fog_old = _fog_image(seen) if seen.size() != now.size() else null
	_fog_fade = 1.0 if _fog_old != null else 0.0
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
	var a := world()
	var p := _player()
	var cells := a.prop_cells("Y")
	var best_d := INF
	for i in mini(cells.size(), a.waystones.size()):
		var w := a.waystones[i]
		if not Story.waystones.has(w.id):
			continue
		# 지도를 열면 지금 있는 곳에서 가장 가까운 탑이 골라져 있다
		var d := LevelMap.cell_center(cells[i]).distance_to(p.global_position)
		if d < best_d:
			best_d = d
			selected = targets.size()
		targets.append({"waystone": w, "cell": cells[i], "pos": world_pos(Vector2(cells[i]) + Vector2(0.5, 0.5))})


## 세계 축소판 그림 (칸마다 그 구역의 지형 색)
func _texture(a: AreaData) -> ImageTexture:
	if _textures.has(a.id):
		return _textures[a.id]
	var m := a.level_map()
	var img := Image.create(maxi(m.width, 1), maxi(m.height, 1), false, Image.FORMAT_RGBA8)
	for y in m.height:
		for x in m.width:
			var cell := Vector2i(x, y)
			var z := a.zone_at(cell)
			var floor_color := z.map_floor_color if z != null else a.map_floor_color
			var wall_color := z.map_wall_color if z != null else a.map_wall_color
			if m.is_wall(cell):
				# 아래가 바닥인 벽은 조금 밝게 (입체감)
				img.set_pixel(x, y, wall_color.lightened(0.18) if m.is_floor(cell + Vector2i.DOWN) else wall_color)
			elif m.is_pit(cell):
				img.set_pixel(x, y, wall_color.darkened(0.5))
			else:
				var shade := 0.06 if (x * 7 + y * 13) % 5 == 0 else 0.0
				img.set_pixel(x, y, floor_color.darkened(shade))
	var tex := ImageTexture.create_from_image(img)
	_textures[a.id] = tex
	return tex


## 안개 그림: 밝혀지지 않은 칸을 구름결 무늬로 덮는다 (칸 하나 = 2×2 점)
func _fog_image(zones: Array[String]) -> ImageTexture:
	var a := world()
	var m := a.level_map()
	var img := Image.create(m.width * 2, m.height * 2, false, Image.FORMAT_RGBA8)
	for y in m.height:
		for x in m.width:
			if is_revealed(Vector2i(x, y), zones):
				continue
			for dy in 2:
				for dx in 2:
					var fx := x * 2 + dx
					var fy := y * 2 + dy
					img.set_pixel(fx, fy, COLOR_FOG_A if ((fx / 3) + (fy / 3)) % 2 == 0 else COLOR_FOG_B)
	return ImageTexture.create_from_image(img)


## 지금 위치 (지도 좌표)
func _here() -> Variant:
	var p := _player()
	if world() == null or p == null:
		return null
	return world_pos(p.global_position / LevelMap.TILE_SIZE)


func _refresh() -> void:
	if targets.is_empty():
		_info.text = DB.story.text_no_waystone
		var here: Variant = _here()
		_set_camera_target(here if here != null else Vector2.ZERO)
	else:
		_info.text = (targets[selected]["waystone"] as WaystoneData).display_name
		_set_camera_target(targets[selected]["pos"])
	_canvas.queue_redraw()


## 그 지점이 창 가운데에 오게 (지도 밖은 보이지 않게 가둔다)
func _set_camera_target(point: Vector2) -> void:
	var limit := (world_size() - VIEW.size).max(Vector2.ZERO)
	_camera_target = (point - VIEW.size * 0.5).clamp(Vector2.ZERO, limit).round()


func _draw_map() -> void:
	var a := world()
	if a == null:
		return
	var size := world_size()
	var now := revealed_zones()
	_canvas.draw_set_transform(-camera.round())
	_canvas.draw_texture_rect(_texture(a), Rect2(Vector2.ZERO, size), false)
	# 안개 (새로 밝혀진 곳은 옛 안개가 옅어지며 걷힌다)
	if _fog_now != null:
		_canvas.draw_texture_rect(_fog_now, Rect2(Vector2.ZERO, size), false)
	if _fog_old != null and _fog_fade > 0.0:
		_canvas.draw_texture_rect(_fog_old, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, _fog_fade))
	for z in a.zones:
		var rect := Rect2(world_pos(Vector2(z.rect.position)), Vector2(z.rect.size) * tile_px())
		var known := now.has(z.id) and _fog_fade < 0.5
		var label := z.display_name if known else DB.story.text_unknown_area
		var width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE_SMALL).x
		var at := Vector2(rect.get_center().x - width * 0.5, rect.position.y - 3.0).round()
		_canvas.draw_string(_font, at + Vector2.ONE, label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE_SMALL, Color(0.05, 0.04, 0.08))
		_canvas.draw_string(_font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE_SMALL, Color(1, 1, 1, 1.0 if known else 0.45))
	# 탑: 밝혀진 땅의 탑은 꺼져 있어도 자리가 보인다
	var cells := a.prop_cells("Y")
	for i in mini(cells.size(), a.waystones.size()):
		var on := Story.waystones.has(a.waystones[i].id)
		if on or is_revealed(cells[i], now):
			_draw_tower(world_pos(Vector2(cells[i]) + Vector2(0.5, 0.5)), on)
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
	_fog_fade = maxf(_fog_fade - delta / REVEAL_SECONDS, 0.0)
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
	teleport_requested.emit((t["waystone"] as WaystoneData).id)


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
