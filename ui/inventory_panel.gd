class_name InventoryPanel
extends CanvasLayer
## 인벤토리 화면 (스토리판). 키 하나(기본 Tab)로 열고, 열려 있는 동안 게임이 멈춘다.
## 네모 칸에 아이콘이 놓이고, 칸에 마우스를 올리면(또는 방향키로 고르면) 이름·설명·능력치 글상자가 뜬다.
##  - 왼쪽: 장착 칸(무기 + 투구·갑옷·바지), 스킬 칸(Q·F), 보유 스킬
##  - 오른쪽: 소지품 칸 (장착한 것은 장착 칸으로 옮겨져 여기엔 없다)
##  - 클릭·Enter: 장착 / 사용 / 읽기 / 스킬을 Q 에 지정.  우클릭·F: 스킬을 F 에 지정.  입은 갑옷 칸을 누르면 벗는다
##  - 방향키·WASD 로 칸 이동, Esc·Tab 닫기
## 스킬 지정과 장착 변경은 전투 중·보스방에서는 못 한다. 소모품 사용·자료 읽기는 언제나 된다.
## 내용은 전부 data 에서 온다 (아이템 = data/items/*.tres, 글 = data/inventory.tres).
# TODO(안드로이드 추가 때): 터치 조작

## 칸 종류
const KIND_WEAPON := "weapon"
const KIND_ARMOR := "armor"
const KIND_SKILL_Q := "skill_q"
const KIND_SKILL_F := "skill_f"
const KIND_SKILL := "skill"
const KIND_BAG := "bag"

## 칸 한 변 (px), 칸 사이 간격
const SLOT := 20.0
const GAP := 2.0
## 소지품 칸: 가로 × 세로
const BAG_COLS := 8
const BAG_ROWS := 5
const LEFT_X := 12.0
const BAG_X := 132.0
const TOP_Y := 34.0
## 왼쪽 묶음(장착 / 스킬 / 보유 스킬) 사이 세로 간격
const ROW_STEP := 40.0
## 글상자 폭 (px)
const TIP_WIDTH := 150.0
const COLOR_SLOT := Color(0.13, 0.11, 0.17)
const COLOR_BORDER := Color(0.36, 0.32, 0.42)
const COLOR_SELECTED := Color(0.97, 0.78, 0.35)
const COLOR_LOCKED := Color(0.08, 0.07, 0.1)
const NOTICE_SECONDS := 1.6

## 지금 진행 중인 런 (StoryMain 이 넣어 준다)
var run: RunController
var is_open: bool = false
## 칸 목록: { "kind": 종류, "rect": Rect2, "entry": ItemData·SkillData·null }
var slots: Array[Dictionary] = []
## 고른 칸 번호
var selected: int = 0
## 자료를 읽는 중
var reading: bool = false
## 읽고 있는 자료 id, 주운 직후 바로 펼친 것인지
var _reading_id: String = ""
var _direct_read: bool = false

var _root: Control
var _canvas: Control
var _tip: PanelContainer
var _tip_label: Label
var _notice: Label
var _help: Label
var _doc_root: Control
var _doc_text: Label
var _notice_left: float = 0.0
var _was_paused: bool = false
var _item_icons: SpriteFrames
var _skill_icons: SpriteFrames
var _font: Font


func is_showing() -> bool:
	return is_open


func _ready() -> void:
	layer = 94
	add_to_group(Crosshair.POINTER_GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_item_icons = DB.theme.load_sheet("items")
	_skill_icons = DB.theme.load_sheet("skill_icons")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.07, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_add_caption("인벤토리", Vector2(LEFT_X, 6), COLOR_SELECTED)
	_add_caption("장착", Vector2(LEFT_X, TOP_Y - 13))
	_add_caption("스킬", Vector2(LEFT_X, TOP_Y + ROW_STEP - 13))
	_add_caption("보유 스킬", Vector2(LEFT_X, TOP_Y + ROW_STEP * 2 - 13))
	_add_caption("소지품", Vector2(BAG_X, TOP_Y - 13))
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_slots)
	_root.add_child(_canvas)
	_font = UiText.make_label().get_theme_font(&"font")
	_notice = UiText.make_label()
	_notice.position = Vector2(0, 152)
	_notice.size = Vector2(320, 12)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override(&"font_color", Color(0.95, 0.5, 0.45))
	_notice.visible = false
	_root.add_child(_notice)
	_help = UiText.make_label()
	_help.position = Vector2(0, 165)
	_help.size = Vector2(320, 12)
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help.modulate.a = 0.7
	_root.add_child(_help)
	# 칸에 올리면 뜨는 글상자
	_tip = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.05, 0.1, 0.97)
	style.border_color = Color(0.77, 0.54, 0.33)
	style.set_border_width_all(1)
	style.set_content_margin_all(3)
	_tip.add_theme_stylebox_override(&"panel", style)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_label = UiText.make_label()
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_tip_label.custom_minimum_size.x = TIP_WIDTH - 6.0
	_tip.add_child(_tip_label)
	_tip.visible = false
	_root.add_child(_tip)
	# 자료 읽기 화면
	_doc_root = Control.new()
	_doc_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_doc_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_doc_root)
	var doc_bg := ColorRect.new()
	doc_bg.color = Color(0.04, 0.03, 0.07, 1.0)
	doc_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_doc_root.add_child(doc_bg)
	_doc_text = UiText.make_label()
	_doc_text.position = Vector2(30, 14)
	_doc_text.size = Vector2(260, 140)
	_doc_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_doc_root.add_child(_doc_text)
	var doc_help := UiText.make_label("Esc 닫기")
	doc_help.position = Vector2(0, 165)
	doc_help.size = Vector2(320, 12)
	doc_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	doc_help.modulate.a = 0.7
	_doc_root.add_child(doc_help)
	_doc_root.visible = false
	_root.visible = false
	Events.inventory_changed.connect(func() -> void:
		if is_open:
			_refresh())


func _add_caption(text: String, pos: Vector2, color: Color = Color(1, 1, 1, 0.6)) -> void:
	var label := UiText.make_label(text)
	label.position = pos
	label.add_theme_color_override(&"font_color", color)
	_root.add_child(label)


func _player() -> Player:
	return run.level.player if run != null and run.level != null else null


## 지금 열 수 있는지 (게임 중이고 주인공이 조작 가능한 상태)
func can_open() -> bool:
	var p := _player()
	return p != null and not run.paused and not p.is_dead() and not p.cutscene_lock


func open() -> bool:
	if is_open or not can_open():
		return false
	is_open = true
	reading = false
	_doc_root.visible = false
	_was_paused = get_tree().paused
	get_tree().paused = true
	_notice.visible = false
	_notice_left = 0.0
	_refresh()
	_root.visible = true
	return true


func close() -> void:
	if not is_open:
		return
	is_open = false
	reading = false
	_direct_read = false
	_root.visible = false
	get_tree().paused = _was_paused


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		_notice.visible = _notice_left > 0.0


func _show_notice(text: String) -> void:
	_notice.text = text
	_notice.visible = true
	_notice_left = NOTICE_SECONDS


func current_notice() -> String:
	return _notice.text if _notice.visible else ""


static func _slot_rect(x: float, y: float) -> Rect2:
	return Rect2(x, y, SLOT, SLOT)


## 칸을 다시 채운다 (장착·스킬·보유 스킬·소지품)
func _build_slots() -> void:
	var inv := Story.inventory
	var step := SLOT + GAP
	slots = []
	slots.append({"kind": KIND_WEAPON, "rect": _slot_rect(LEFT_X, TOP_Y), "entry": inv.equipped_weapon()})
	# 갑옷류 칸: 투구·갑옷·바지 (data/inventory.tres 의 armor_slot_names 순서)
	var n_armor := 1
	for armor_slot: String in DB.inventory.armor_slot_names:
		slots.append({"kind": KIND_ARMOR, "slot": armor_slot, "rect": _slot_rect(LEFT_X + n_armor * step, TOP_Y),
			"entry": inv.equipped_armor(armor_slot)})
		n_armor += 1
	slots.append({"kind": KIND_SKILL_Q, "rect": _slot_rect(LEFT_X, TOP_Y + ROW_STEP), "entry": inv.skill_data(Inventory.SLOT_Q)})
	slots.append({"kind": KIND_SKILL_F, "rect": _slot_rect(LEFT_X + step, TOP_Y + ROW_STEP), "entry": inv.skill_data(Inventory.SLOT_F)})
	var i := 0
	for s in DB.skills:
		if inv.owned_skills.has(s.id):
			slots.append({"kind": KIND_SKILL, "rect": _slot_rect(LEFT_X + i * step, TOP_Y + ROW_STEP * 2), "entry": s})
			i += 1
	var bag: Array[ItemData] = []
	for item in inv.owned(ItemData.Category.values()):
		# 장착한 것 하나는 장착 칸에 있다
		if inv.count(item.id) - (1 if inv.is_equipped(item.id) else 0) > 0:
			bag.append(item)
	for n in BAG_COLS * BAG_ROWS:
		var rect := _slot_rect(BAG_X + (n % BAG_COLS) * step, TOP_Y + (n / BAG_COLS) * step)
		slots.append({"kind": KIND_BAG, "rect": rect, "entry": bag[n] if n < bag.size() else null})


## 칸에 든 것의 id ("" = 빈 칸)
static func entry_id(entry: Variant) -> String:
	if entry is SkillData:
		return (entry as SkillData).id
	if entry is ItemData:
		return (entry as ItemData).id
	return ""


## 해당 종류 칸들에 든 것의 id (빈 칸 제외)
func ids(kind: String) -> Array[String]:
	var out: Array[String] = []
	for s in slots:
		if s["kind"] == kind and s["entry"] != null:
			out.append(entry_id(s["entry"]))
	return out


## 그 종류의 칸 중 id 가 든 칸을 고른다 (id 가 "" 이면 그 종류의 첫 칸). 골랐으면 true
func select(kind: String, id: String = "") -> bool:
	for i in slots.size():
		if slots[i]["kind"] == kind and (id.is_empty() or entry_id(slots[i]["entry"]) == id):
			selected = i
			_update_view()
			return true
	return false


## 소지품 칸 구석에 보일 개수 (1개면 숨김)
func _count_of(slot: Dictionary) -> int:
	var item := slot["entry"] as ItemData
	if item == null or slot["kind"] != KIND_BAG:
		return 0
	return Story.inventory.count(item.id) - (1 if Story.inventory.is_equipped(item.id) else 0)


## 글상자의 글: 이름 + 분류 + 설명 + 능력치
static func tooltip_text(entry: Variant) -> String:
	var skill := entry as SkillData
	if skill != null:
		return "%s\n%s" % [skill.display_name, detail_text(entry)]
	var item := entry as ItemData
	if item == null:
		return ""
	return "%s\n%s" % [item.display_name, detail_text(entry)]


## 분류 + 설명 + 능력치
static func detail_text(entry: Variant) -> String:
	var skill := entry as SkillData
	if skill != null:
		return "[%s]\n%s" % [skill.tag, skill.description]
	var item := entry as ItemData
	var lines: Array[String] = ["[%s]" % DB.inventory.category_names[item.category], item.description]
	if item.weapon != null:
		var w := item.weapon
		lines.append("사격 %d · 탄창 %d · 간격 %d" % [w.gun.projectile.damage, w.gun.magazine_size, w.gun.fire_interval_ticks])
		lines.append("근접 %d · 범위 %d · 간격 %d" % [w.melee.damage, roundi(w.melee.radius), w.melee.active_ticks + w.melee.recovery_ticks])
		lines.append("반사 %d · 탄약 +%d" % [w.parry.reflect_damage, w.parry.ammo_on_parry])
	for mod in item.stat_mods:
		lines.append(mod_text(mod))
	return "\n".join(lines)


## 스탯 수정 한 줄: "최대 체력 +1", "이동 속도 ×0.9"
static func mod_text(mod: StatMod) -> String:
	var stat_name := String(DB.inventory.stat_names.get(mod.stat, mod.stat))
	if mod.op == StatMod.Op.ADD:
		return "%s %s%s" % [stat_name, "+" if mod.value >= 0.0 else "", _num(mod.value)]
	return "%s ×%s" % [stat_name, _num(mod.value)]


## 2 → "2", 0.9 → "0.9"
static func _num(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else String.num(value, 2)


func _refresh() -> void:
	_build_slots()
	selected = clampi(selected, 0, slots.size() - 1)
	_update_view()


## 고른 칸이 바뀌었을 때: 글상자·도움말·그림 갱신
func _update_view() -> void:
	var slot := slots[selected]
	var text := tooltip_text(slot["entry"])
	if slot["entry"] == null and slot["kind"] == KIND_SKILL_F and not Story.inventory.skill2_unlocked():
		text = DB.inventory.text_skill2_locked
	elif slot["entry"] == null and slot["kind"] == KIND_ARMOR:
		# 빈 장착 칸: 무슨 칸인지
		text = "%s 칸" % DB.inventory.armor_slot_names[slot["slot"]]
	_tip.visible = not text.is_empty()
	if _tip.visible:
		_tip_label.text = text
		_tip.reset_size()
		# 칸 오른쪽 아래에 띄우되 화면 밖으로 나가지 않게
		var rect: Rect2 = slot["rect"]
		var size := _tip.get_combined_minimum_size()
		var pos := rect.position + Vector2(SLOT + 3.0, 0.0)
		if pos.x + size.x > 318.0:
			pos.x = rect.position.x - size.x - 3.0
		pos.y = clampf(pos.y, 2.0, maxf(162.0 - size.y, 2.0))
		_tip.position = pos
	_help.text = _help_text(slot)
	_canvas.queue_redraw()


func _help_text(slot: Dictionary) -> String:
	var action := ""
	var entry: Variant = slot["entry"]
	match String(slot["kind"]):
		KIND_SKILL:
			action = "클릭·Enter %s 지정" % Settings.key_name(&"skill")
			if Story.inventory.skill2_unlocked():
				action += " · 우클릭·%s %s 지정" % [Settings.key_name(&"skill2"), Settings.key_name(&"skill2")]
		KIND_ARMOR:
			action = "클릭·Enter 벗기" if entry != null else ""
		KIND_BAG:
			var item := entry as ItemData
			if item != null:
				match item.category:
					ItemData.Category.WEAPON, ItemData.Category.ARMOR:
						action = "클릭·Enter 장착"
					ItemData.Category.CONSUMABLE:
						action = "클릭·Enter 사용"
					ItemData.Category.DOCUMENT:
						action = "클릭·Enter 읽기"
	return ("%s · Esc 닫기" % action) if not action.is_empty() else "방향키 이동 · Esc 닫기"


func _draw_slots() -> void:
	for i in slots.size():
		var slot := slots[i]
		var rect: Rect2 = slot["rect"]
		var locked: bool = slot["kind"] == KIND_SKILL_F and not Story.inventory.skill2_unlocked()
		_canvas.draw_rect(rect, COLOR_LOCKED if locked else COLOR_SLOT)
		_canvas.draw_rect(rect, COLOR_SELECTED if i == selected else COLOR_BORDER, false)
		var icon := _icon_of(slot["entry"])
		if icon != null:
			_canvas.draw_texture(icon, rect.position + Vector2(2, 2))
		var count := _count_of(slot)
		if count > 1:
			var text := str(count)
			var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE_SMALL).x
			var at := rect.position + Vector2(SLOT - width - 1.0, SLOT - 1.0)
			_canvas.draw_string(_font, at + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE_SMALL, Color(0.05, 0.04, 0.08))
			_canvas.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE_SMALL, Color.WHITE)
		# 칸 이름표: 스킬 칸의 키 이름, 보유 스킬에 지정된 키
		var tag := _tag_of(slot)
		if not tag.is_empty():
			_canvas.draw_string(_font, rect.position + Vector2(1, 9), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE_SMALL, COLOR_SELECTED)


func _icon_of(entry: Variant) -> Texture2D:
	var skill := entry as SkillData
	if skill != null:
		return _skill_icons.get_frame_texture(skill.icon, 0)
	var item := entry as ItemData
	if item != null and _item_icons.has_animation(item.icon):
		return _item_icons.get_frame_texture(item.icon, 0)
	return null


## 칸 왼쪽 위 글자: 보유 스킬이 어느 키에 지정돼 있는지, 빈 스킬 칸의 키 이름
func _tag_of(slot: Dictionary) -> String:
	var inv := Story.inventory
	match String(slot["kind"]):
		KIND_SKILL:
			var id := entry_id(slot["entry"])
			if inv.skill_ids[Inventory.SLOT_Q] == id:
				return Settings.key_name(&"skill")
			if inv.skill_ids[Inventory.SLOT_F] == id and inv.skill2_unlocked():
				return Settings.key_name(&"skill2")
		KIND_ARMOR:
			# 빈 칸에는 칸 이름 첫 글자 (투·갑·바)
			return String(DB.inventory.armor_slot_names[slot["slot"]]).left(1) if slot["entry"] == null else ""
		KIND_SKILL_Q:
			return Settings.key_name(&"skill") if slot["entry"] == null else ""
		KIND_SKILL_F:
			return Settings.key_name(&"skill2") if slot["entry"] == null and inv.skill2_unlocked() else ""
	return ""


## 고른 칸에 확정 동작. to_f 가 참이면 스킬을 스킬2(F) 칸에 지정
func activate(to_f: bool = false) -> void:
	if not is_open or reading:
		return
	var inv := Story.inventory
	var slot := slots[selected]
	var entry: Variant = slot["entry"]
	if entry == null:
		return
	var restricted := CombatState.is_restricted(get_tree())
	match String(slot["kind"]):
		KIND_SKILL:
			if to_f and not inv.skill2_unlocked():
				_show_notice(DB.inventory.text_skill2_locked)
			elif restricted:
				_show_notice(DB.inventory.text_in_combat)
			elif inv.set_skill(Inventory.SLOT_F if to_f else Inventory.SLOT_Q, (entry as SkillData).id):
				Audio.play("ui_confirm")
		KIND_ARMOR:
			if restricted:
				_show_notice(DB.inventory.text_in_combat)
			elif inv.equip((entry as ItemData).id):
				Audio.play("ui_confirm")
		KIND_BAG:
			var item := entry as ItemData
			match item.category:
				ItemData.Category.WEAPON, ItemData.Category.ARMOR:
					if restricted:
						_show_notice(DB.inventory.text_in_combat)
					elif inv.equip(item.id):
						Audio.play("ui_confirm")
				ItemData.Category.CONSUMABLE:
					if inv.use(item.id, _player()):
						Audio.play("ui_confirm")
						_show_notice(DB.inventory.text_used)
					else:
						_show_notice(DB.inventory.text_cannot_use)
				ItemData.Category.DOCUMENT:
					_show_document(item)


func _show_document(item: ItemData) -> void:
	_doc_text.text = "%s\n\n%s" % [item.display_name, item.document_text]
	_doc_root.visible = true
	reading = true
	_reading_id = item.id


## 자료를 주운 직후 등: 인벤토리를 열고 곧바로 그 자료를 펼친다 (닫으면 게임으로 돌아간다)
func read_document(item_id: String) -> bool:
	var item := DB.item(item_id)
	if item == null or item.category != ItemData.Category.DOCUMENT or not open():
		return false
	select(KIND_BAG, item_id)
	_direct_read = true
	_show_document(item)
	return true


func _close_document() -> void:
	reading = false
	_doc_root.visible = false
	var id := _reading_id
	_reading_id = ""
	if _direct_read:
		_direct_read = false
		close()
	if not id.is_empty():
		Story.set_flag("read:%s" % id)
		Events.document_read.emit(id)


## 방향키: 그 방향에 있는 가장 가까운 칸으로
func move(dir: Vector2) -> void:
	var from: Vector2 = (slots[selected]["rect"] as Rect2).get_center()
	var best := -1
	var best_score := INF
	for i in slots.size():
		if i == selected:
			continue
		var d := (slots[i]["rect"] as Rect2).get_center() - from
		var along := d.dot(dir)
		if along <= 1.0:
			continue
		# 옆으로 벗어난 만큼 불리하게
		var score := along + absf(d.dot(dir.orthogonal())) * 3.0
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		selected = best
		Audio.play("ui_move")
		_update_view()


func _slot_at(pos: Vector2) -> int:
	for i in slots.size():
		if (slots[i]["rect"] as Rect2).has_point(pos):
			return i
	return -1


func _input(event: InputEvent) -> void:
	# 마우스: 올리면 고르고, 누르면 확정 (우클릭은 스킬2 칸에 지정)
	if not is_open or reading:
		return
	var motion := event as InputEventMouseMotion
	var button := event as InputEventMouseButton
	if motion != null:
		var i := _slot_at(_canvas.get_local_mouse_position())
		if i >= 0 and i != selected:
			selected = i
			_update_view()
	elif button != null and button.pressed \
			and (button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_RIGHT):
		var i := _slot_at(_canvas.get_local_mouse_position())
		if i >= 0:
			selected = i
			_update_view()
			activate(button.button_index == MOUSE_BUTTON_RIGHT)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if not is_open:
		if event.is_action_pressed(&"skill_menu") and run != null:
			open()
			get_viewport().set_input_as_handled()
		return
	if reading:
		if event.is_action_pressed(&"pause") or event.is_action_pressed(&"menu_confirm") or event.is_action_pressed(&"skill_menu"):
			_close_document()
	elif event.is_action_pressed(&"skill_menu") or event.is_action_pressed(&"pause"):
		close()
	elif event.is_action_pressed(&"move_left") or event.is_action_pressed(&"ui_left"):
		move(Vector2.LEFT)
	elif event.is_action_pressed(&"move_right") or event.is_action_pressed(&"ui_right"):
		move(Vector2.RIGHT)
	elif event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
		move(Vector2.UP)
	elif event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
		move(Vector2.DOWN)
	elif event.is_action_pressed(&"menu_confirm") or event.is_action_pressed(&"dodge"):
		activate(false)
	elif event.is_action_pressed(&"skill2"):
		activate(true)
	# 열려 있는 동안에는 아래(게임·일시정지)로 입력을 넘기지 않는다
	get_viewport().set_input_as_handled()
