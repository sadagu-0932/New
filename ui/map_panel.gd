class_name MapPanel
extends CanvasLayer
## 지도 화면 (스토리판). 키 하나(기본 M)로 열고, 열려 있는 동안 게임이 멈춘다.
## 세상 한 장이 그대로 지도가 된다. 지역은 구불구불한 모양이고, 밝혀지지 않은 지역은 안개에 덮여 있다.
##  - 지명은 마우스가 가까이 갔을 때만 뜬다. 아직 열리지 않은 곳에는 글자를 띄우지 않는다
##  - 처음엔 출발한 연구소 둘레의 원만 밝혀져 있고, 웨이스톤 탑을 켜면 그 탑을 가운데로 한 둥근 땅이 밝혀진다.
##    원의 가장자리는 점점 흐려지고, 원끼리 겹치면 밝혀진 곳이 자연스럽게 이어진다.
##    새로 밝혀진 곳은 지도를 열 때 안개가 걷히며 드러난다
##  - 마우스 휠: 크게/작게 (가장 작게 하면 세상 전체가 한눈에) · 끌기: 지도 움직이기
##  - 탑 표시는 작게 있다가 마우스가 가까이 오면 커지면서 이름이 뜬다. 그때 누르면 작은 창이 떠서
##    순간이동을 고른다 (전투 중·보스방에서는 불가)
##  - 빈 곳을 누르면 그 자리에 핀을 꽂는 창이 뜬다. 핀을 누르면 지울 수 있다
##  - 키보드: 방향키·WASD 로 움직이고(가운데 십자 표시가 가리키는 곳), Q·E 로 작게·크게, Enter 로 그 자리를 누른다
## 색·크기 단계는 data (data/areas/world.tres, data/story.tres)
# TODO(안드로이드 추가 때): 터치 조작 (끌기·두 손가락 확대)

signal teleport_requested(waystone_id: String)

## 지도가 보이는 창 (화면 좌표)
const VIEW := Rect2(8, 16, 304, 134)
const COLOR_FOG_A := Color(0.11, 0.1, 0.15)
## 안개 그림의 한 점이 덮는 칸 수
const FOG_STEP := 4
const COLOR_TOWER_ON := Color(0.62, 0.89, 0.94)
const COLOR_TOWER_OFF := Color(0.5, 0.48, 0.55)
const COLOR_SELECTED := Color(0.97, 0.78, 0.35)
const COLOR_PIN := Color(0.9, 0.3, 0.32)
const NOTICE_SECONDS := 1.6
## 안개가 걷히는 시간 (초), 키보드로 움직이는 빠르기 (px/초)
const REVEAL_SECONDS := 1.2
const KEY_PAN_SPEED := 140.0
## 이 거리(px) 안을 누르면 그 핀을 누른 것으로 본다. 탑은 그림 위에 올라가야 한다 (TOWER_HIT) 이만큼 끌면 누르기가 아니라 끌기
const PICK_RADIUS := 5.0
## 탑 그림 위로 친 범위 (탑 밑동 기준, 지도 px): 작은 탑 그림 / 커진 탑 그림
const TOWER_HIT := Rect2(-3, -7, 6, 9)
const TOWER_HIT_BIG := Rect2(-5, -15, 10, 17)
const DRAG_THRESHOLD := 3.0

## 작은 창의 선택지
const OPT_TELEPORT := "여기로 순간이동"
const OPT_PIN := "핀 꽂기"
const OPT_UNPIN := "핀 지우기"
const OPT_CANCEL := "취소"

## 지금 진행 중인 런 (StoryMain 이 넣어 준다)
var run: RunController
var is_open: bool = false
## 켜 둔 탑: [{ "waystone": WaystoneData, "cell": 맵 칸 }]
var targets: Array[Dictionary] = []
## 지도 왼쪽 위가 화면에서 밀려난 정도 (px)
var camera: Vector2 = Vector2.ZERO
## 확대·축소 단계 (0 = 세상 전체가 한눈에, 클수록 크게). 한 번 고르면 게임을 끌 때까지 유지된다
var zoom_index: int = -1
static var _px: float = 0.0
## 작은 창: 열려 있는지, 선택지, 고른 줄, 눌린 칸, 눌린 탑 id·핀 번호
var popup_open: bool = false
var popup_options: Array[String] = []
var popup_selected: int = 0
var popup_cell: Vector2i = Vector2i.ZERO
## 지금 가리키고 있는(마우스가 가까이 온) 켠 탑 — targets 의 번호, 없으면 -1
var hovered: int = -1
var _popup_waystone: String = ""
var _popup_pin: int = -1

var _root: Control
var _canvas: Control
var _fog_layer: Control
var _overlay: Control
var _info: Label
var _notice: Label
var _popup: PanelContainer
var _popup_title: Label
var _popup_rows: Array[Label] = []
var _textures: Dictionary = {}
var _was_paused: bool = false
var _notice_left: float = 0.0
var _blink: float = 0.0
## 지금 안개, 지난번에 본 안개(걷히는 중), 옛 안개의 진하기 (1 → 0)
var _fog_now: ImageTexture
var _fog_old: ImageTexture
var _fog_fade: float = 0.0
var _font: Font
var _dragging: bool = false
var _drag_moved: float = 0.0
## 마우스를 쓰는 중인지 (아니면 가운데 십자 표시가 가리키는 곳을 쓴다)
var _use_mouse: bool = false


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
	title.position = Vector2(0, 4)
	title.size = Vector2(320, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)
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
	var back := ColorRect.new()
	back.color = Color(0.05, 0.05, 0.09)
	back.size = VIEW.size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(back)
	_canvas = Control.new()
	_canvas.size = VIEW.size
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_map)
	clip.add_child(_canvas)
	# 안개 층: 부드럽게 늘여 그려 원 가장자리가 점점 흐려지게
	_fog_layer = Control.new()
	_fog_layer.size = VIEW.size
	_fog_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fog_layer.draw.connect(_draw_fog)
	clip.add_child(_fog_layer)
	# 맨 위 층: 지명·탑·핀·지금 위치
	_overlay = Control.new()
	_overlay.size = VIEW.size
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	clip.add_child(_overlay)
	_info = UiText.make_label()
	_info.position = Vector2(0, 151)
	_info.size = Vector2(320, 12)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_color_override(&"font_color", COLOR_SELECTED)
	_root.add_child(_info)
	_notice = UiText.make_label()
	_notice.position = Vector2(0, 151)
	_notice.size = Vector2(320, 12)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override(&"font_color", Color(0.95, 0.5, 0.45))
	_notice.visible = false
	_root.add_child(_notice)
	var help := UiText.make_label("휠 크게/작게 · 끌어서 이동 · 클릭 탑·핀 · Esc 닫기")
	help.position = Vector2(0, 165)
	help.size = Vector2(320, 12)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.modulate.a = 0.7
	_root.add_child(help)
	# 눌렀을 때 뜨는 작은 창
	_popup = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.05, 0.1, 0.98)
	style.border_color = Color(0.77, 0.54, 0.33)
	style.set_border_width_all(1)
	style.set_content_margin_all(3)
	_popup.add_theme_stylebox_override(&"panel", style)
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(box)
	_popup_title = UiText.make_label()
	_popup_title.add_theme_color_override(&"font_color", COLOR_SELECTED)
	box.add_child(_popup_title)
	for i in 2:
		var row := UiText.make_label()
		box.add_child(row)
		_popup_rows.append(row)
	_popup.visible = false
	_root.add_child(_popup)
	_root.visible = false


## 지금 지역 (지도가 있는 지역이 아니면 null)
static func world() -> AreaData:
	var a := DB.area(Story.area)
	return a if a != null and a.on_map else null


## 지도를 밝히는 원들: [Vector3(칸 x, 칸 y, 반지름 칸)]
## 출발한 연구소 둘레의 원 + 켠 탑마다 그 탑을 가운데로 한 원. 원끼리 겹치면 자연스럽게 이어진다
static func reveal_circles(waystone_ids: Array = []) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var a := world()
	if a == null:
		return out
	var ids: Array = waystone_ids if not waystone_ids.is_empty() else Story.waystones
	var start := a.landmark("lab_pos")
	if start.x >= 0:
		var center := Vector2(start) + Vector2(a.landmark("lab_size")) * 0.5
		out.append(Vector3(center.x, center.y, DB.story.map_start_radius))
	var cells := a.prop_cells("Y")
	for i in mini(cells.size(), a.waystones.size()):
		if ids.has(a.waystones[i].id):
			out.append(Vector3(cells[i].x + 0.5, cells[i].y + 0.5, DB.story.map_reveal_radius))
	return out


## 그 자리(칸)의 안개 진하기: 0 = 다 밝혀짐, 1 = 가려짐. 원 가장자리로 갈수록 점점 짙어진다
static func fog_at(cell: Vector2, circles: Array[Vector3]) -> float:
	var fade := maxf(DB.story.map_reveal_fade, 0.01)
	var best := 1.0
	for c in circles:
		var d := cell.distance_to(Vector2(c.x, c.y))
		best = minf(best, clampf((d - (c.z - fade)) / fade, 0.0, 1.0))
	return best


## 그 칸이 지도에서 밝혀져 있는지 (안개가 절반보다 옅은지)
static func is_revealed(cell: Vector2i, circles: Array[Vector3] = []) -> bool:
	var list := circles if not circles.is_empty() else reveal_circles()
	return fog_at(Vector2(cell) + Vector2(0.5, 0.5), list) < 0.5


## 지도에서 밝혀진 지역 id (지역 한가운데가 밝혀진 곳)
static func revealed_zones() -> Array[String]:
	var out: Array[String] = []
	var a := world()
	if a == null:
		return out
	var circles := reveal_circles()
	for z in a.zones:
		if fog_at(a.zone_center(z.id), circles) < 0.5:
			out.append(z.id)
	return out


## 지도에서 (일부라도) 밝혀진 묶음 id
static func revealed_groups() -> Array[String]:
	var out: Array[String] = []
	var a := world()
	if a == null:
		return out
	var zone_ids := revealed_zones()
	for z in a.zones:
		if zone_ids.has(z.id) and not out.has(z.group):
			out.append(z.group)
	return out


## 지도에서 맵 한 칸의 크기 (px). 확대·축소 단계에 따라 바뀐다
static func tile_px() -> float:
	return _px if _px > 0.0 else float(maxi(DB.story.map_tile_px, 1))


## 세상 전체가 지도 창에 다 들어오는 한 칸 크기
static func fit_px() -> float:
	var a := world()
	if a == null:
		return 1.0
	var m := a.level_map()
	return minf(VIEW.size.x / maxf(m.width, 1.0), VIEW.size.y / maxf(m.height, 1.0))


## 확대·축소 단계들 (한 칸 px, 작은 것부터). 맨 앞은 "전체 보기"
static func zoom_levels() -> Array[float]:
	var out: Array[float] = [fit_px()]
	for v: float in DB.story.map_zoom_levels:
		if v > out[0] + 0.01:
			out.append(v)
	return out


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


## 지도에 보일 지역 이름 (아직 열리지 않은 곳은 빈 글 — 아무것도 띄우지 않는다)
static func zone_label(z: ZoneData) -> String:
	return z.display_name if revealed_zones().has(z.id) else ""


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
	_close_popup()
	_dragging = false
	_use_mouse = false
	if zoom_index < 0:
		# 처음 열 때의 크기: data/story.tres 의 map_tile_px 에 가장 가까운 단계
		var levels := zoom_levels()
		zoom_index = levels.size() - 1
		for i in levels.size():
			if levels[i] >= float(DB.story.map_tile_px) - 0.01:
				zoom_index = i
				break
	_px = zoom_levels()[zoom_index]
	_build_targets()
	# 안개: 지난번에 본 모습(옛 안개)에서 지금 모습으로 걷힌다
	var seen: Array = []
	for id: String in Story.waystones:
		if Story.has_flag("map_seen:%s" % id):
			seen.append(id)
		Story.set_flag("map_seen:%s" % id)
	_fog_now = _fog_image(reveal_circles())
	var old_circles := reveal_circles(seen) if not seen.is_empty() else reveal_circles(["-"])
	_fog_old = _fog_image(old_circles) if seen.size() != Story.waystones.size() else null
	_fog_fade = 1.0 if _fog_old != null else 0.0
	# 지금 있는 곳을 가운데에
	var here: Variant = _here()
	center_on(here if here != null else world_size() * 0.5)
	_refresh()
	_root.visible = true
	return true


func close() -> void:
	if not is_open:
		return
	is_open = false
	_close_popup()
	_root.visible = false
	get_tree().paused = _was_paused


func _build_targets() -> void:
	targets = []
	var a := world()
	var cells := a.prop_cells("Y")
	for i in mini(cells.size(), a.waystones.size()):
		if Story.waystones.has(a.waystones[i].id):
			targets.append({"waystone": a.waystones[i], "cell": cells[i]})


## 확대·축소 단계를 고른다 (0 = 전체 보기). anchor = 그대로 있어야 할 화면 속 지점 (창 안 좌표, 기본은 가운데)
func set_zoom(index: int, anchor: Vector2 = VIEW.size * 0.5) -> void:
	var levels := zoom_levels()
	var before := tile_px()
	zoom_index = clampi(index, 0, levels.size() - 1)
	_px = levels[zoom_index]
	if is_open:
		# anchor 가 가리키던 칸이 그 자리에 그대로 있게
		var cell := (camera + anchor) / before
		camera = cell * _px - anchor
		_clamp_camera()
		_refresh()


## 그 지점(지도 좌표)이 창 가운데에 오게
func center_on(point: Vector2) -> void:
	camera = point - VIEW.size * 0.5
	_clamp_camera()


## 지도 밖이 보이지 않게 가둔다. 지도가 창보다 작으면(전체 보기) 가운데에 놓는다
func _clamp_camera() -> void:
	var size := world_size()
	var limit := (size - VIEW.size).max(Vector2.ZERO)
	camera = camera.clamp(Vector2.ZERO, limit)
	if size.x < VIEW.size.x:
		camera.x = -(VIEW.size.x - size.x) * 0.5
	if size.y < VIEW.size.y:
		camera.y = -(VIEW.size.y - size.y) * 0.5


## 세계 축소판 그림 (칸마다 그 땅 종류의 색)
func _texture(a: AreaData) -> ImageTexture:
	if _textures.has(a.id):
		return _textures[a.id]
	var m := a.level_map()
	var img := Image.create(maxi(m.width, 1), maxi(m.height, 1), false, Image.FORMAT_RGBA8)
	var floor_default := Color(0.56, 0.52, 0.62)
	var wall_default := Color(0.24, 0.21, 0.3)
	for y in m.height:
		for x in m.width:
			var cell := Vector2i(x, y)
			var g := a.ground_at(cell)
			var floor_color: Color = a.ground_floor_colors.get(g, floor_default)
			var wall_color: Color = a.ground_wall_colors.get(g, wall_default)
			if m.is_wall(cell):
				# 아래가 바닥인 벽은 조금 밝게 (입체감), 나머지 숲은 칸마다 살짝 다르게
				var shade := 0.18 if m.is_floor(cell + Vector2i.DOWN) else (0.05 if (x * 5 + y * 3) % 7 == 0 else 0.0)
				img.set_pixel(x, y, wall_color.lightened(shade))
			elif m.is_pit(cell):
				# 물: 그 땅의 벽 색(물빛)을 물결처럼 살짝 다르게
				img.set_pixel(x, y, wall_color.lightened(0.08 if (x + y * 2) % 5 == 0 else 0.0))
			else:
				img.set_pixel(x, y, floor_color.darkened(0.06 if (x * 7 + y * 13) % 5 == 0 else 0.0))
	var tex := ImageTexture.create_from_image(img)
	_textures[a.id] = tex
	return tex


## 안개 그림: 칸 FOG_STEP 개마다 한 점, 점마다 안개 진하기(알파). 부드럽게 늘여 그려 원 가장자리가 점점 흐려진다
func _fog_image(circles: Array[Vector3]) -> ImageTexture:
	var a := world()
	var m := a.level_map()
	var w := ceili(float(m.width) / FOG_STEP) + 1
	var h := ceili(float(m.height) / FOG_STEP) + 1
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var alpha := fog_at(Vector2(x, y) * FOG_STEP, circles)
			if alpha > 0.0:
				img.set_pixel(x, y, Color(COLOR_FOG_A, alpha))
	return ImageTexture.create_from_image(img)


## 지금 위치 (지도 좌표)
func _here() -> Variant:
	var p := _player()
	if world() == null or p == null:
		return null
	return world_pos(p.global_position / LevelMap.TILE_SIZE)


## 지금 가리키는 곳 (창 안 좌표): 마우스를 쓰는 중이면 마우스, 아니면 창 가운데
func pointer() -> Vector2:
	return _canvas.get_local_mouse_position() if _use_mouse else VIEW.size * 0.5


## 창 안 좌표 → 맵 칸
func cell_at(view_point: Vector2) -> Vector2i:
	return Vector2i(((camera + view_point) / tile_px()).floor())


func _refresh() -> void:
	var a := world()
	hovered = _target_at(camera + pointer()) if a != null and not popup_open else -1
	var z := a.zone_at(cell_at(pointer())) if a != null else null
	# 가리키는 곳: "묶음 · 지역" (가려진 곳은 ???)
	if z == null:
		_info.text = ""
	elif revealed_zones().has(z.id):
		_info.text = "%s · %s" % [z.group_name, z.display_name]
	else:
		_info.text = ""       # 아직 열리지 않은 곳: 아무것도 띄우지 않는다
	_canvas.queue_redraw()
	_fog_layer.queue_redraw()
	_overlay.queue_redraw()


func _draw_map() -> void:
	var a := world()
	if a == null:
		return
	var size := world_size()
	_canvas.draw_set_transform(-camera.round())
	_canvas.draw_texture_rect(_texture(a), Rect2(Vector2.ZERO, size), false)
	_canvas.draw_set_transform(Vector2.ZERO)


## 안개 층 (부드럽게 늘여 그린다). 새로 밝혀진 곳은 옛 안개가 옅어지며 걷힌다
func _draw_fog() -> void:
	if world() == null:
		return
	var m := world().level_map()
	# 안개 그림의 점 하나 = 칸 FOG_STEP 개. 점의 가운데가 그 칸 위치에 오게 반 점만큼 당긴다
	var rect := Rect2(Vector2.ONE * -0.5 * FOG_STEP * tile_px(), Vector2(ceili(float(m.width) / FOG_STEP) + 1, ceili(float(m.height) / FOG_STEP) + 1) * FOG_STEP * tile_px())
	_fog_layer.draw_set_transform(-camera.round())
	if _fog_now != null:
		_fog_layer.draw_texture_rect(_fog_now, rect, false)
	if _fog_old != null and _fog_fade > 0.0:
		_fog_layer.draw_texture_rect(_fog_old, rect, false, Color(1, 1, 1, _fog_fade))
	_fog_layer.draw_set_transform(Vector2.ZERO)


## 맨 위 층: 지명·탑·핀·지금 위치·십자 표시
func _draw_overlay() -> void:
	var a := world()
	if a == null:
		return
	var circles := reveal_circles()
	_overlay.draw_set_transform(-camera.round())
	# 이름: 가리키는 곳(마우스) 가까이에 있는 것만 뜬다. 아직 열리지 않은 곳에는 아무것도 띄우지 않는다
	if _fog_fade < 0.5:
		for label: Dictionary in labels_near_pointer():
			_draw_label(label["text"], label["pos"], true)
	# 탑: 평소엔 작게, 마우스(가리키는 곳)가 가까이 오면 커지면서 이름이 뜬다 → 누르면 순간이동 창
	# 밝혀진 땅의 탑은 꺼져 있어도 자리가 보인다 (커지지 않는다)
	var cells := a.prop_cells("Y")
	var hover_cell := Vector2i(-1, -1)
	if hovered >= 0 and hovered < targets.size():
		hover_cell = targets[hovered]["cell"]
	for i in mini(cells.size(), a.waystones.size()):
		var on := Story.waystones.has(a.waystones[i].id)
		if on or is_revealed(cells[i], circles):
			var big := on and cells[i] == hover_cell
			var at := world_pos(Vector2(cells[i]) + Vector2(0.5, 0.5))
			_draw_tower(at, on, big)
			if big:
				_draw_label(a.waystones[i].display_name, at - Vector2(0, 4), true)
	for pin: Variant in Story.pins:
		_draw_pin(world_pos(Vector2(float(pin[0]) + 0.5, float(pin[1]) + 0.5)))
	var here: Variant = _here()
	if here != null:
		var at: Vector2 = here
		_overlay.draw_circle(at, 2.5, Color(0.05, 0.04, 0.08))
		_overlay.draw_circle(at, 1.5, Color.WHITE if int(_blink * 4.0) % 2 == 0 else COLOR_SELECTED)
	_overlay.draw_set_transform(Vector2.ZERO)
	# 키보드로 쓸 때의 가운데 십자 표시
	if not _use_mouse and not popup_open:
		var c := (VIEW.size * 0.5).round()
		_overlay.draw_line(c + Vector2(-4, 0), c + Vector2(5, 0), COLOR_SELECTED)
		_overlay.draw_line(c + Vector2(0, -4), c + Vector2(0, 5), COLOR_SELECTED)


## 지금 띄울 지명들: [{ "text": 이름, "pos": 지도 좌표 }]
## 열린 곳의 이름 중 가리키는 곳에서 가까운 것만 (작게 볼 때는 묶음 이름, 크게 보면 작은 지역 이름)
func labels_near_pointer() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var a := world()
	if a == null:
		return out
	var at := camera + pointer()
	var reach := DB.story.map_label_radius_px
	if tile_px() >= DB.story.map_area_names_px:
		var open_zones := revealed_zones()
		for z in a.zones:
			var pos := world_pos(a.zone_center(z.id))
			if open_zones.has(z.id) and pos.distance_to(at) <= reach:
				out.append({"text": z.display_name, "pos": pos})
	else:
		var groups := a.groups()
		for g: String in revealed_groups():
			var pos := world_pos(a.group_center(g))
			if pos.distance_to(at) <= reach:
				out.append({"text": String(groups[g]), "pos": pos})
	return out


## 지도 위의 글자 (그 자리보다 조금 위에, 가운데 맞춤)
func _draw_label(label: String, center: Vector2, bright: bool) -> void:
	var width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE_SMALL).x
	var at := (center - Vector2(width * 0.5, 12.0)).round()
	_overlay.draw_string(_font, at + Vector2.ONE, label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE_SMALL, Color(0.05, 0.04, 0.08))
	_overlay.draw_string(_font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE_SMALL, Color(1, 1, 1, 1.0 if bright else 0.35))


## 탑 표시 (밑동이 base 에 오게). big = 가리키고 있어 커진 모습
func _draw_tower(base: Vector2, on: bool, big: bool = false) -> void:
	var body := Color(0.8, 0.78, 0.84) if on else COLOR_TOWER_OFF
	var top := COLOR_TOWER_ON if on else Color(0.3, 0.28, 0.34)
	var p := base.round()
	var dark := Color(0.05, 0.04, 0.08)
	if big:
		_overlay.draw_rect(Rect2(p + Vector2(-5, -15), Vector2(10, 17)), COLOR_SELECTED)
		_overlay.draw_rect(Rect2(p + Vector2(-4, -14), Vector2(8, 15)), dark)
		_overlay.draw_rect(Rect2(p + Vector2(-3, -9), Vector2(6, 9)), body)
		_overlay.draw_rect(Rect2(p + Vector2(-3, -13), Vector2(6, 4)), top)
		_overlay.draw_rect(Rect2(p + Vector2(-1, -12), Vector2(2, 2)), Color.WHITE)
	else:
		_overlay.draw_rect(Rect2(p + Vector2(-2, -6), Vector2(4, 7)), dark)
		_overlay.draw_rect(Rect2(p + Vector2(-1, -3), Vector2(2, 3)), body)
		_overlay.draw_rect(Rect2(p + Vector2(-1, -5), Vector2(2, 2)), top)


## 핀 표시 (뾰족한 끝이 base 에 오게)
func _draw_pin(base: Vector2) -> void:
	var p := base.round()
	_overlay.draw_line(p, p + Vector2(0, -6), Color(0.05, 0.04, 0.08), 2.0)
	_overlay.draw_circle(p + Vector2(0, -7), 3.0, Color(0.05, 0.04, 0.08))
	_overlay.draw_circle(p + Vector2(0, -7), 2.0, COLOR_PIN)
	_overlay.draw_rect(Rect2(p + Vector2(-1, -8), Vector2(1, 1)), Color.WHITE)


func _process(delta: float) -> void:
	if not is_open:
		return
	_blink += delta
	_fog_fade = maxf(_fog_fade - delta / REVEAL_SECONDS, 0.0)
	if not popup_open:
		# 키보드로 지도 움직이기
		var move := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		if move != Vector2.ZERO:
			_use_mouse = false
			camera += move * KEY_PAN_SPEED * delta
			_clamp_camera()
	_refresh()
	if _notice_left > 0.0:
		_notice_left -= delta
		_notice.visible = _notice_left > 0.0
		_info.visible = not _notice.visible


func current_notice() -> String:
	return _notice.text if _notice.visible else ""


func _show_notice(text: String) -> void:
	_notice.text = text
	_notice.visible = true
	_info.visible = false
	_notice_left = NOTICE_SECONDS


## 그 칸 가까이에 있는 켠 탑 (없으면 -1). 가깝다 = 화면에서 PICK_RADIUS px 안
## 지도 좌표의 그 점이 켠 탑 그림 위에 올라가 있는지 (없으면 -1).
## 작은 탑 그림 위에 올라가야 커지고, 커진 뒤에는 커진 그림 안에 있는 동안 그대로 (떨리지 않게)
func _target_at(map_point: Vector2) -> int:
	for i in targets.size():
		var base := world_pos(Vector2(targets[i]["cell"] as Vector2i) + Vector2(0.5, 0.5)).round()
		var rect := TOWER_HIT_BIG if i == hovered else TOWER_HIT
		if Rect2(base + rect.position, rect.size).has_point(map_point):
			return i
	return -1


func _pin_near(cell: Vector2i) -> int:
	var best := -1
	var best_d := PICK_RADIUS
	for i in Story.pins.size():
		var pin: Array = Story.pins[i]
		var d := (Vector2(float(pin[0]), float(pin[1])) - Vector2(cell)).length() * tile_px()
		if d <= best_d:
			best_d = d
			best = i
	return best


## 지도의 그 칸을 누른다: 탑이면 순간이동 창, 핀이면 지우기 창, 빈 곳이면 핀 꽂기 창
## map_point: 실제로 누른 지도 좌표 (탑 그림 위인지 볼 때 씀, 없으면 그 칸 가운데)
func click_cell(cell: Vector2i, map_point: Vector2 = Vector2.INF) -> void:
	var a := world()
	if a == null or popup_open:
		return
	var m := a.level_map()
	if cell.x < 0 or cell.y < 0 or cell.x >= m.width or cell.y >= m.height:
		return
	var point := map_point if map_point.is_finite() else world_pos(Vector2(cell) + Vector2(0.5, 0.5))
	var t := _target_at(point)
	var pin := _pin_near(cell)
	popup_cell = cell
	_popup_waystone = ""
	_popup_pin = -1
	if t >= 0:
		var w := targets[t]["waystone"] as WaystoneData
		popup_cell = targets[t]["cell"]
		_popup_waystone = w.id
		_popup_title.text = w.display_name
		popup_options = [OPT_TELEPORT, OPT_CANCEL]
	elif pin >= 0:
		_popup_pin = pin
		popup_cell = Vector2i(int(Story.pins[pin][0]), int(Story.pins[pin][1]))
		_popup_title.text = "핀"
		popup_options = [OPT_UNPIN, OPT_CANCEL]
	else:
		if Story.pins.size() >= DB.story.map_max_pins:
			_show_notice(DB.story.text_pins_full % DB.story.map_max_pins)
			return
		var z := a.zone_at(cell)
		_popup_title.text = zone_label(z) if z != null else ""
		popup_options = [OPT_PIN, OPT_CANCEL]
	_popup_title.visible = not _popup_title.text.is_empty()
	popup_open = true
	popup_selected = 0
	Audio.play("ui_move")
	_refresh_popup()
	# 누른 자리 옆에 띄우되 화면 밖으로 나가지 않게
	_popup.reset_size()
	var size := _popup.get_combined_minimum_size()
	var at := VIEW.position + world_pos(Vector2(popup_cell) + Vector2(0.5, 0.5)) - camera + Vector2(8, -4)
	at.x = clampf(at.x, 2.0, 318.0 - size.x)
	at.y = clampf(at.y, 2.0, 178.0 - size.y)
	_popup.position = at.round()
	_popup.visible = true


func _refresh_popup() -> void:
	for i in _popup_rows.size():
		_popup_rows[i].visible = i < popup_options.size()
		if i < popup_options.size():
			_popup_rows[i].text = ("> " if i == popup_selected else "  ") + popup_options[i]
			_popup_rows[i].add_theme_color_override(&"font_color", COLOR_SELECTED if i == popup_selected else Color.WHITE)


func _close_popup() -> void:
	popup_open = false
	if _popup != null:
		_popup.visible = false


## 작은 창의 선택지를 고른다
func choose(index: int) -> void:
	if not popup_open or index < 0 or index >= popup_options.size():
		return
	var option := popup_options[index]
	_close_popup()
	match option:
		OPT_TELEPORT:
			if CombatState.is_restricted(get_tree()):
				_show_notice(DB.story.text_cannot_teleport)
				return
			Audio.play("ui_confirm")
			var id := _popup_waystone
			close()
			teleport_requested.emit(id)
		OPT_PIN:
			Story.pins.append([popup_cell.x, popup_cell.y])
			Audio.play("ui_confirm")
		OPT_UNPIN:
			if _popup_pin >= 0 and _popup_pin < Story.pins.size():
				Story.pins.remove_at(_popup_pin)
				Audio.play("ui_confirm")
	_refresh()


## 작은 창에서 마우스가 가리키는 줄 (없으면 -1)
func _popup_row_at(screen_point: Vector2) -> int:
	for i in popup_options.size():
		if _popup_rows[i].get_global_rect().has_point(screen_point):
			return i
	return -1


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var motion := event as InputEventMouseMotion
	var button := event as InputEventMouseButton
	if motion == null and button == null:
		return
	_use_mouse = true
	var screen_point := _root.get_local_mouse_position()
	var view_point := _canvas.get_local_mouse_position()
	var in_view := Rect2(Vector2.ZERO, VIEW.size).has_point(view_point)
	if popup_open:
		# 작은 창이 떠 있는 동안: 줄 고르기, 바깥을 누르면 닫기
		var row := _popup_row_at(screen_point)
		if motion != null and row >= 0 and row != popup_selected:
			popup_selected = row
			_refresh_popup()
		elif button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			if row >= 0:
				choose(row)
			else:
				_close_popup()
		get_viewport().set_input_as_handled()
		return
	if motion != null:
		if _dragging:
			_drag_moved += motion.relative.length()
			if _drag_moved > DRAG_THRESHOLD:
				camera -= motion.relative
				_clamp_camera()
	elif button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed and in_view:
		set_zoom(zoom_index + 1, view_point)
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed and in_view:
		set_zoom(zoom_index - 1, view_point)
	elif button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed and in_view:
			_dragging = true
			_drag_moved = 0.0
		elif not button.pressed and _dragging:
			_dragging = false
			# 끌지 않고 뗐으면 그 자리를 누른 것
			if _drag_moved <= DRAG_THRESHOLD and in_view:
				click_cell(cell_at(view_point), camera + view_point)
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if not is_open:
		if event.is_action_pressed(&"map") and run != null:
			open()
			get_viewport().set_input_as_handled()
		return
	if popup_open:
		if event.is_action_pressed(&"pause"):
			_close_popup()
		elif event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up") \
				or event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
			popup_selected = posmod(popup_selected + 1, popup_options.size())
			_refresh_popup()
		elif event.is_action_pressed(&"menu_confirm") or event.is_action_pressed(&"dodge"):
			choose(popup_selected)
	elif event.is_action_pressed(&"map") or event.is_action_pressed(&"pause"):
		close()
	elif event.is_action_pressed(&"skill"):
		set_zoom(zoom_index - 1)
	elif event.is_action_pressed(&"interact"):
		set_zoom(zoom_index + 1)
	elif event.is_action_pressed(&"menu_confirm") or event.is_action_pressed(&"dodge"):
		# 키보드: 가운데 십자 표시가 가리키는 곳을 누른다
		_use_mouse = false
		click_cell(cell_at(VIEW.size * 0.5), camera + VIEW.size * 0.5)
	get_viewport().set_input_as_handled()
