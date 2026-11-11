extends Node
## 데이터 저장소 (오토로드 DB).
## 모든 수치는 res://data/*.tres 에 있고, 코드는 여기서만 꺼내 쓴다.
## 수치를 바꿀 때는 data/ 파일만 고치면 된다.

var game_config: GameConfig = preload("res://data/game_config.tres")
var player: PlayerData = preload("res://data/player.tres")
var dodge: DodgeData = preload("res://data/dodge.tres")
var gun: GunData = preload("res://data/gun.tres")
var melee: MeleeData = preload("res://data/melee.tres")
var parry: ParryData = preload("res://data/parry.tres")
var stealth: StealthData = preload("res://data/stealth.tres")
var advanced: AdvancedTechData = preload("res://data/advanced_tech.tres")
var target_dummy: TargetDummyData = preload("res://data/props/target_dummy.tres")
var test_turret: TestTurretData = preload("res://data/props/test_turret.tres")
var crystal_switch: CrystalSwitchData = preload("res://data/props/crystal_switch.tres")
var spike: SpikeData = preload("res://data/hazards/spike.tres")
var boulder: BoulderData = preload("res://data/hazards/boulder.tres")
## 적 종류 이름 → 데이터 (맵 글자와의 연결은 Level.SPAWNS)
var enemies: Dictionary = {
	"charger": preload("res://data/enemies/charger.tres"),
	"charger_weak": preload("res://data/enemies/charger_weak.tres"),
	"shooter": preload("res://data/enemies/shooter.tres"),
	"spreader": preload("res://data/enemies/spreader.tres"),
	"golem": preload("res://data/bosses/golem.tres"),
}
## 스킬 목록 (스킬 설정 창에 이 순서로 나온다)
var skills: Array[SkillData] = [
	preload("res://data/skills/blink.tres"),
	preload("res://data/skills/absorb.tres"),
	preload("res://data/skills/decoy.tres"),
	preload("res://data/skills/shockwave.tres"),
	preload("res://data/skills/mark.tres"),
]
var audio: AudioData = preload("res://data/audio.tres")
var feel: FeelData = preload("res://data/feel.tres")
var touch: TouchData = preload("res://data/touch.tres")
var inventory: InventoryConfig = preload("res://data/inventory.tres")
var save: SaveConfig = preload("res://data/save.tres")
var story: StoryData = preload("res://data/story.tres")
var theme: ThemeData = preload("res://data/theme.tres")


## 아이템 id → ItemData. res://data/items/ 아래의 .tres 를 전부 읽는다 (아이템 추가 = 파일 추가)
const ITEMS_DIR := "res://data/items"
var items: Dictionary = {}
var _items_sorted: Array[ItemData] = []


## 지역 id → AreaData (res://data/areas/ 아래의 .tres 전부)
const AREAS_DIR := "res://data/areas"
const ENEMIES_DIR := "res://data/enemies"
var areas: Dictionary = {}


func area(area_id: String) -> AreaData:
	return areas.get(area_id)


## 폴더의 .tres 파일 경로들 (내보낸 빌드에서는 .tres.remap 으로 보인다)
static func tres_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for file in dir.get_files():
		var file_name := file.trim_suffix(".remap")
		if file_name.ends_with(".tres") and not out.has("%s/%s" % [dir_path, file_name]):
			out.append("%s/%s" % [dir_path, file_name])
	out.sort()
	return out


func _ready() -> void:
	for path in tres_files(AREAS_DIR):
		var a := load(path) as AreaData
		if a != null and not a.id.is_empty():
			areas[a.id] = a
	# 지역별 적 수치(data/enemies/ 에 파일만 추가)도 파일 이름으로 등록한다
	for path in tres_files(ENEMIES_DIR):
		var key := path.get_file().get_basename()
		if not enemies.has(key):
			enemies[key] = load(path)
	_load_items(ITEMS_DIR)
	# 내보낸 빌드에서 폴더 읽기가 안 되면 바로 알 수 있게
	if items.is_empty() or areas.is_empty():
		push_error("data/items 또는 data/areas 를 읽지 못함 (아이템 %d개, 지역 %d개)" % [items.size(), areas.size()])
	_items_sorted.assign(items.values())
	_items_sorted.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		if a.category != b.category:
			return a.category < b.category
		return a.order < b.order if a.order != b.order else a.id < b.id)


func _load_items(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub_dir in dir.get_directories():
		_load_items("%s/%s" % [dir_path, sub_dir])
	for file in dir.get_files():
		# 내보낸 빌드에서는 .tres 가 .tres.remap 으로 보인다
		var file_name := file.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var item := load("%s/%s" % [dir_path, file_name]) as ItemData
		if item == null or item.id.is_empty():
			push_warning("아이템 파일을 읽지 못함: %s/%s" % [dir_path, file_name])
		elif items.has(item.id):
			push_warning("아이템 id 중복: %s" % item.id)
		else:
			items[item.id] = item


func item(item_id: String) -> ItemData:
	return items.get(item_id)


## 모든 아이템 (분류 → order → id 순)
func items_sorted() -> Array[ItemData]:
	return _items_sorted


## 스킬 id → SkillData (없으면 null)
func find_skill(skill_id: String) -> SkillData:
	for s in skills:
		if s.id == skill_id:
			return s
	return null


func skill_by_id(skill_id: String) -> SkillData:
	for s in skills:
		if s.id == skill_id:
			return s
	return skills[0] if not skills.is_empty() else null
