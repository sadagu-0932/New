class_name ItemData
extends Resource
## 아이템 정의. res://data/items/ 아래에 .tres 를 넣으면 자동으로 등록된다 (코드 수정 없음).

enum Category { WEAPON, ARMOR, CONSUMABLE, MATERIAL, DOCUMENT }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.MATERIAL
## 아이콘 (art 테마의 items 시트 애니메이션 이름)
@export var icon: StringName = &""
## 목록에서의 순서 (작을수록 위)
@export var order: int = 0
## 갑옷류: 어느 칸에 끼는지 (helmet 투구 · armor 갑옷 · pants 바지)
@export var armor_slot: String = "armor"
## 무기: 전투 수치
@export var weapon: WeaponData
## 무기·갑옷: 장착하고 있는 동안의 스탯 수정
@export var stat_mods: Array[StatMod] = []
## 소모품: 썼을 때 효과
@export var use_effects: Array[ItemEffect] = []
## 자료(문서): 읽을 내용
@export_multiline var document_text: String = ""


func is_equipment() -> bool:
	return category == Category.WEAPON or category == Category.ARMOR
