class_name InventoryConfig
extends Resource
## 인벤토리 규칙·글. 실제 값은 res://data/inventory.tres

## 새 게임 때 갖고 시작하는 아이템 (id → 개수)
@export var start_items: Dictionary = {}
@export var start_weapon: String = ""
@export var start_armor: String = ""
## 처음부터 보유한 스킬 id
@export var start_skills: Array[String] = []
## 처음에 Q 에 지정된 스킬 ("" = game_config 의 default_skill_id)
@export var start_skill_q: String = ""
## 스킬2(F) 칸이 열리는 스토리 진행도 이름
@export var skill2_unlock_flag: String = ""
## 스탯 이름 → 화면에 보일 이름
@export var stat_names: Dictionary = {}
## 탭 이름 (스킬·무기·갑옷·아이템 순)
@export var tab_names: Array[String] = []
## 아이템 분류 이름 (ItemData.Category 순)
@export var category_names: Array[String] = []
@export var text_in_combat: String = ""
@export var text_skill2_locked: String = ""
@export var text_empty: String = ""
@export var text_equipped: String = ""
@export var text_used: String = ""
@export var text_cannot_use: String = ""
