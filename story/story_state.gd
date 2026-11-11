extends Node
## 스토리판 진행 상태 (오토로드 Story): 지금 있는 지역, 스토리 진행도, 활성화한 웨이스톤, 인벤토리.
## 저장 파일에는 이 내용 + 플레이어 상태(위치·체력·탄약·스킬)가 들어간다 (StorySaveManager).

const AREA_PROLOGUE := "prologue"

## 지금 있는 지역 id
var area: String = AREA_PROLOGUE
## 스토리 진행도 (이름 → 값). 예: "prologue_done"
var flags: Dictionary = {}
## 활성화한 웨이스톤 id
# TODO(S4): 웨이스톤
var waystones: Array = []
## 인벤토리·장착·스킬 지정
var inventory: Inventory = Inventory.new()


func _ready() -> void:
	reset()


## 새 게임 상태로
func reset() -> void:
	area = AREA_PROLOGUE
	flags = {}
	waystones = []
	inventory = Inventory.new()
	inventory.reset_to_start()


func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func to_dict() -> Dictionary:
	return {
		"area": area,
		"flags": flags.duplicate(true),
		"waystones": waystones.duplicate(),
		"inventory": inventory.to_dict(),
	}


func from_dict(d: Dictionary) -> void:
	reset()
	area = String(d.get("area", AREA_PROLOGUE))
	flags = (d.get("flags", {}) as Dictionary).duplicate(true)
	waystones = (d.get("waystones", []) as Array).duplicate()
	inventory.from_dict(d.get("inventory", {}))


## 자동저장의 "인벤토리가 변했는지" 비교용
func inventory_signature() -> String:
	return inventory.signature()
