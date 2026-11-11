class_name Inventory
extends RefCounted
## 인벤토리·장착 (스토리판). Story 오토로드가 하나 갖고 있고 저장 파일에 들어간다.
##  - 아이템: id → 개수
##  - 장착: 원거리 무기 한 칸, 갑옷 한 칸
##  - 스킬: 보유 스킬 중 Q(0번 칸)·F(1번 칸)에 지정
## 바뀌면 Events.inventory_changed, 전투 수치에 영향을 주는 변경이면 Events.loadout_changed 도 낸다.

const SLOT_Q := 0
const SLOT_F := 1

var items: Dictionary = {}
var weapon_id: String = ""
var armor_id: String = ""
## 보유 스킬
var owned_skills: Array[String] = []
## 칸별 지정 스킬 id ("" = 비어 있음)
var skill_ids: Array[String] = ["", ""]


## 새 게임 시작 상태 (data/inventory.tres)
func reset_to_start() -> void:
	var cfg := DB.inventory
	items = {}
	for id: String in cfg.start_items:
		items[id] = int(cfg.start_items[id])
	weapon_id = cfg.start_weapon
	armor_id = cfg.start_armor
	owned_skills = cfg.start_skills.duplicate()
	var q := cfg.start_skill_q if not cfg.start_skill_q.is_empty() else DB.game_config.default_skill_id
	skill_ids = [q, ""]


func count(id: String) -> int:
	return int(items.get(id, 0))


func has(id: String) -> bool:
	return count(id) > 0


func add(id: String, amount: int = 1) -> void:
	if amount <= 0 or DB.item(id) == null:
		return
	items[id] = count(id) + amount
	Events.inventory_changed.emit()


func remove(id: String, amount: int = 1) -> bool:
	if count(id) < amount:
		return false
	items[id] = count(id) - amount
	if items[id] <= 0:
		items.erase(id)
	Events.inventory_changed.emit()
	return true


## 가진 아이템 중 해당 분류들 (목록 순서대로)
func owned(categories: Array) -> Array[ItemData]:
	var out: Array[ItemData] = []
	for item in DB.items_sorted():
		if has(item.id) and categories.has(item.category):
			out.append(item)
	return out


func equipped_weapon() -> ItemData:
	return DB.item(weapon_id)


func equipped_armor() -> ItemData:
	return DB.item(armor_id)


func is_equipped(id: String) -> bool:
	return not id.is_empty() and (id == weapon_id or id == armor_id)


## 장착. 무기는 바꿔 끼우기만 되고, 갑옷은 입은 것을 다시 고르면 벗는다. 바뀌었으면 true
func equip(id: String) -> bool:
	var item := DB.item(id)
	if item == null or not has(id):
		return false
	match item.category:
		ItemData.Category.WEAPON:
			if weapon_id == id or item.weapon == null:
				return false
			weapon_id = id
		ItemData.Category.ARMOR:
			armor_id = "" if armor_id == id else id
		_:
			return false
	Events.inventory_changed.emit()
	Events.loadout_changed.emit()
	return true


## 스킬2(F) 칸이 열렸는지 (프롤로그가 끝나면 열린다)
func skill2_unlocked() -> bool:
	return Story.has_flag(DB.inventory.skill2_unlock_flag)


## 칸에 스킬 지정. 다른 칸에 이미 있던 스킬이면 서로 맞바꾼다. 바뀌었으면 true
# TODO: 스킬 2개 사용 규칙(중복 선택·쿨타임 공유)은 임시 — 중복 불가, 쿨타임 따로
func set_skill(slot: int, id: String) -> bool:
	if slot < 0 or slot >= skill_ids.size() or not owned_skills.has(id) or skill_ids[slot] == id:
		return false
	if slot == SLOT_F and not skill2_unlocked():
		return false
	var other := 1 - slot
	if skill_ids[other] == id:
		# Q 는 비워 둘 수 없다 → 맞바꿀 것이 없으면 거절
		if other == SLOT_Q and skill_ids[slot].is_empty():
			return false
		skill_ids[other] = skill_ids[slot]
	skill_ids[slot] = id
	Events.inventory_changed.emit()
	Events.loadout_changed.emit()
	return true


func skill_data(slot: int) -> SkillData:
	var id := skill_ids[slot]
	if id.is_empty() or (slot == SLOT_F and not skill2_unlocked()):
		return null
	# DB.skills 를 직접 읽지 않는다: 이 스크립트는 DB 가 스킬 data 를 preload 하는 도중에 컴파일될 수 있어
	# (blink.tres → Skill → Player → Loadout → Story → Inventory) 내보낸 빌드에서 순환 참조가 된다
	return DB.find_skill(id)


## 소모품 사용. 효과가 하나라도 들어갔으면 하나 쓰고 true
func use(id: String, player: Player) -> bool:
	var item := DB.item(id)
	if item == null or player == null or not has(id) or item.category != ItemData.Category.CONSUMABLE:
		return false
	var applied := false
	for effect in item.use_effects:
		if effect != null and apply_effect(effect, player):
			applied = true
	if not applied:
		return false
	remove(id)
	return true


## 효과 하나 적용. 아무 변화가 없으면(이미 가득) false
static func apply_effect(effect: ItemEffect, player: Player) -> bool:
	match effect.kind:
		"heal":
			if player.health.current >= player.health.maximum:
				return false
			player.health.heal(effect.amount)
			Events.player_hp_changed.emit(player.health.current, player.health.maximum)
			return true
		"ammo":
			if player.ammo.current >= player.ammo.maximum:
				return false
			player.ammo.add(effect.amount)
			return true
	push_warning("모르는 아이템 효과: %s" % effect.kind)
	return false


func to_dict() -> Dictionary:
	return {
		"items": items.duplicate(),
		"weapon": weapon_id,
		"armor": armor_id,
		"owned_skills": owned_skills.duplicate(),
		"skills": skill_ids.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	reset_to_start()
	if d.is_empty():
		return
	items = {}
	for id: String in d.get("items", {}):
		if DB.item(id) != null:
			items[id] = int(d["items"][id])
	weapon_id = String(d.get("weapon", weapon_id))
	armor_id = String(d.get("armor", ""))
	if DB.item(weapon_id) == null:
		weapon_id = DB.inventory.start_weapon
	var owned_list: Array = d.get("owned_skills", [])
	if not owned_list.is_empty():
		owned_skills.assign(owned_list)
	var slots: Array = d.get("skills", [])
	for i in mini(slots.size(), skill_ids.size()):
		skill_ids[i] = String(slots[i])


func signature() -> String:
	return JSON.stringify(to_dict())
