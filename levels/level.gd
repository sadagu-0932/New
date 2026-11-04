class_name Level
extends Node2D
## 맵 하나 (타일 + 소품·적 + 플레이어 + 탄 + 이펙트). 맵은 코드로 구성한다.
## 자식 순서 = 매 틱 처리 순서: 타일 → 소품·적 → 플레이어 → 탄 → 이펙트 → 튜토리얼 진행
## (플레이어가 근접 판정을 켠 뒤 같은 틱에 탄이 패링 판정을 본다)

const GROUP_PROJECTILES := &"projectiles"

## 맵 글자 → [스크립트, 적 데이터 이름(DB.enemies 키, 소품은 "")]
## 스크립트에 setup_from_map(글자, 칸) 이 있으면 생성 직후 부른다
const SPAWNS := {
	"D": [preload("res://levels/props/target_dummy.gd"), ""],
	"T": [preload("res://levels/props/test_turret.gd"), ""],
	"G": [preload("res://levels/props/gate.gd"), ""],
	"W": [preload("res://levels/props/crystal_switch.gd"), ""],
	"X": [preload("res://levels/hazards/spike_trap.gd"), ""],
	"x": [preload("res://levels/hazards/spike_trap.gd"), ""],
	"O": [preload("res://levels/hazards/boulder_spawner.gd"), ""],
	"Z": [preload("res://bosses/golem/golem_spawn_point.gd"), ""],
	"C": [preload("res://enemies/charger.gd"), "charger"],
	"c": [preload("res://enemies/charger.gd"), "charger_weak"],
	"S": [preload("res://enemies/shooter.gd"), "shooter"],
	"B": [preload("res://enemies/spreader.gd"), "spreader"],
}

## 글자 맵 파일 경로 (tutorial 이 없을 때)
var map_path: String = ""
## 튜토리얼 (있으면 구간 파일을 이어 붙여 맵을 만들고 진행 관리자를 붙인다)
var tutorial: TutorialData
var map: LevelMap
var player: Player
var props: Node2D
var projectiles: Node2D
var effects: Node2D
var director: TutorialDirector
## 현재 디버그 구간 (0 = 시작 지점, 1~7 = 구간)
var current_section: int = 0


func _ready() -> void:
	if tutorial != null:
		map = LevelMap.parse(tutorial.assemble_text())
	else:
		map = LevelMap.load_from_file(map_path)
	add_child(LevelBuilder.build(map, DB.theme))

	props = Node2D.new()
	props.name = "Props"
	add_child(props)
	for entry: Dictionary in map.props:
		var ch: String = entry["char"]
		var spawn: Array = SPAWNS.get(ch, [])
		if spawn.is_empty():
			push_warning("맵에 모르는 글자: %s" % ch)
			continue
		var node: Node2D = (spawn[0] as GDScript).new()
		if node is Enemy:
			(node as Enemy).data = DB.enemies[spawn[1]]
		node.position = LevelMap.cell_center(entry["cell"])
		if node.has_method(&"setup_from_map"):
			node.call(&"setup_from_map", ch, entry["cell"])
		props.add_child(node)

	player = Player.new()
	player.position = LevelMap.cell_center(map.spawn_cell)
	add_child(player)
	var size := map.pixel_size()
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = size.x
	player.camera.limit_bottom = size.y

	projectiles = Node2D.new()
	projectiles.name = "Projectiles"
	projectiles.add_to_group(GROUP_PROJECTILES)
	add_child(projectiles)

	effects = Node2D.new()
	effects.name = "Effects"
	effects.add_to_group(Effect.GROUP)
	add_child(effects)

	if tutorial != null:
		director = TutorialDirector.new(self, tutorial)
		add_child(director)

	Events.debug_section_step.connect(_on_debug_section_step)


## 디버그: 이전/다음 구간 시작 지점으로 이동
func _on_debug_section_step(delta: int) -> void:
	var sections: Array = map.section_cells.keys()
	if sections.is_empty():
		return
	sections.sort()
	var last: int = sections[sections.size() - 1]
	current_section = clampi(current_section + delta, 0, last)
	var cell := map.spawn_cell
	if map.section_cells.has(current_section):
		cell = map.section_cells[current_section]
	player.teleport(LevelMap.cell_center(cell))
