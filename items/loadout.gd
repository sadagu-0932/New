class_name Loadout
extends RefCounted
## 지금 장착한 것에서 전투 수치를 꺼낸다. 전투 코드는 장비를 직접 보지 않고 여기만 본다.
##  - 스토리판: 인벤토리의 장착 무기·갑옷
##  - 스피드런판(인벤토리 없음): data/gun.tres · melee.tres · parry.tres 그대로, 스탯 수정 없음

static var _default_weapon: WeaponData


static func _equipped() -> Array[ItemData]:
	var out: Array[ItemData] = []
	if not Game.is_story_mode():
		return out
	for item: ItemData in [Story.inventory.equipped_weapon(), Story.inventory.equipped_armor()]:
		if item != null:
			out.append(item)
	return out


## 장착한 무기의 전투 수치
static func weapon() -> WeaponData:
	if Game.is_story_mode():
		var item := Story.inventory.equipped_weapon()
		if item != null and item.weapon != null:
			return item.weapon
	if _default_weapon == null:
		_default_weapon = WeaponData.new()
		_default_weapon.gun = DB.gun
		_default_weapon.melee = DB.melee
		_default_weapon.parry = DB.parry
	return _default_weapon


## 스탯 최종값 = (기본값 + ADD 합) × MUL 곱
static func stat(stat_name: String, base: float) -> float:
	return apply_mods(stat_name, base, _equipped())


static func apply_mods(stat_name: String, base: float, items: Array[ItemData]) -> float:
	var add := 0.0
	var mul := 1.0
	for item in items:
		for mod in item.stat_mods:
			if mod == null or mod.stat != stat_name:
				continue
			if mod.op == StatMod.Op.ADD:
				add += mod.value
			else:
				mul *= mod.value
	return (base + add) * mul
