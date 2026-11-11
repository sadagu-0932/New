class_name MapPanel
extends CanvasLayer
## 지도 화면 (스토리판). 키 하나(기본 M)로 열고, 열려 있는 동안 게임이 멈춘다.
##  - 웨이스톤을 활성화한 곳의 주변만 밝혀져 있고, 나머지는 가려져 있다
##  - 활성화한 웨이스톤을 ←→ 로 골라 Enter 로 순간이동 (전투 중·보스방에서는 불가)
## 지역 배치·크기는 data/areas/*.tres 의 map_pos 와 data/story.tres 의 map_tile_px
# TODO(안드로이드 추가 때): 터치 조작

signal teleport_requested(area_id: String, waystone_id: String)

const COLOR_WALL := Color(0.24, 0.21, 0.3)
const COLOR_FLOOR := Color(0.56, 0.52, 0.62)
const COLOR_PIT := Color(0.1, 0.08, 0.13)
const COLOR_FOG := Color(0.13, 0.11, 0.17)
const COLOR_WAYSTONE := Color(0.62, 0.89, 0.94)
const COLOR_SELECTED := Color(0.97, 0.78, 0.35)
const NOTICE_SECONDS := 1.6

## 지금 진행 중인 런 (StoryMain 이 넣어 준다)
var run: RunController
var is_open: bool = false
## 고른 웨이스톤 (targets 의 번호)
var selected: int = 0
## 순간이동할 수 있는 곳: [{ "area": AreaData, "waystone": WaystoneData, "pos": 지도 좌표 }]
var targets: Array[Dictionary] = []

var _root: Control
var _canvas: Control
var _info: Label
var _notice: Label
var _labels: Array[Label] = []
var _textures: Dictionary = {}
var _was_paused: bool = false
var _notice_left: float = 0.0
var _blink: float = 0.0


func is_showing() -> bool:
	return is_open


func _ready() -> void:
	layer = 94
	add_to_group(Crosshair.POINTER_GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.07, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var title := UiText.make_label("지도")
	title.position = Vector2(0, 6)
	title.size = Vector2(320, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_map)
	_root.add_child(_canvas)
	for a in areas():
		var label := UiText.make_label()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_root.add_child(label)
		_labels.append(label)
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
	var help := UiText.make_label("←→ 웨이스톤 고르기 · Enter 순간이동 · Esc 닫기")
	help.position = Vector2(0, 165)
	help.size = Vector2(320, 12)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.modulate.a = 0.7
	_root.add_child(help)
	_root.visible = false


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
	_refresh()
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
	var px := tile_px()
	for a in areas():
		var cells := a.prop_cells("Y")
		for i in a.waystones.size():
			var w := a.waystones[i]
			if not Story.waystones.has(w.id) or i >= cells.size():
				continue
			if a.id == Story.area and _is_nearest(a, i):
				selected = targets.size()
			targets.append({"area": a, "waystone": w, "pos": Vector2(a.map_pos) + Vector2(cells[i]) * px})


## 지금 지역에서 플레이어와 가장 가까운 웨이스톤인지 (지도를 열면 그것이 골라져 있다)
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


func _texture(a: AreaData) -> ImageTexture:
	if _textures.has(a.id):
		return _textures[a.id]
	var m := a.level_map()
	var img := Image.create(maxi(m.width, 1), maxi(m.height, 1), false, Image.FORMAT_RGBA8)
	for y in m.height:
		for x in m.width:
			var cell := Vector2i(x, y)
			if m.is_wall(cell):
				img.set_pixel(x, y, COLOR_WALL)
			elif m.is_pit(cell):
				img.set_pixel(x, y, COLOR_PIT)
			elif m.is_floor(cell):
				img.set_pixel(x, y, COLOR_FLOOR)
	var tex := ImageTexture.create_from_image(img)
	_textures[a.id] = tex
	return tex


func _refresh() -> void:
	var revealed := revealed_areas()
	var px := tile_px()
	var list := areas()
	for i in list.size():
		var a := list[i]
		var m := a.level_map()
		_labels[i].text = a.display_name if revealed.has(a.id) else DB.story.text_unknown_area
		_labels[i].position = Vector2(a.map_pos.x - 20, a.map_pos.y + m.height * px + 2)
		_labels[i].size = Vector2(m.width * px + 40, 12)
		_labels[i].modulate.a = 1.0 if revealed.has(a.id) else 0.5
	if targets.is_empty():
		_info.text = DB.story.text_no_waystone
	else:
		var t := targets[selected]
		_info.text = "%s · %s" % [(t["area"] as AreaData).display_name, (t["waystone"] as WaystoneData).display_name]
	_canvas.queue_redraw()


func _draw_map() -> void:
	var revealed := revealed_areas()
	var px := float(tile_px())
	for a in areas():
		var m := a.level_map()
		var rect := Rect2(Vector2(a.map_pos), Vector2(m.width, m.height) * px)
		if revealed.has(a.id):
			_canvas.draw_texture_rect(_texture(a), rect, false)
		else:
			# 가려진 지역: 크기만 어렴풋이
			_canvas.draw_rect(rect, COLOR_FOG)
			_canvas.draw_rect(rect, Color(1, 1, 1, 0.08), false)
	for i in targets.size():
		var pos: Vector2 = targets[i]["pos"]
		_canvas.draw_rect(Rect2(pos - Vector2.ONE, Vector2.ONE * (px + 2.0)), COLOR_WAYSTONE)
		if i == selected and int(_blink * 3.0) % 2 == 0:
			_canvas.draw_rect(Rect2(pos - Vector2.ONE * 3.0, Vector2.ONE * (px + 6.0)), COLOR_SELECTED, false)
	var area := DB.area(Story.area)
	var p := _player()
	if area != null and area.on_map and p != null:
		var here := Vector2(area.map_pos) + p.global_position / LevelMap.TILE_SIZE * px
		_canvas.draw_circle(here, 1.5, Color.WHITE if int(_blink * 4.0) % 2 == 0 else COLOR_SELECTED)


func _process(delta: float) -> void:
	if not is_open:
		return
	_blink += delta
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


## 고른 웨이스톤으로 순간이동
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
